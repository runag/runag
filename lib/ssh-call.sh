#!/usr/bin/env bash

#  Copyright 2012-2022 Rùnag project contributors
#
#  Licensed under the Apache License, Version 2.0 (the "License");
#  you may not use this file except in compliance with the License.
#  You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
#  Unless required by applicable law or agreed to in writing, software
#  distributed under the License is distributed on an "AS IS" BASIS,
#  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#  See the License for the specific language governing permissions and
#  limitations under the License.

# ssh::call runs bash scripts on remote hosts.
#
# Functions defined in the current bash interpreter are serialized and,
# along with some selected environment variables, are passed to the remote host to run.
#
# Streams are buffered to make ssh calls resilient to network errors.
#
# First, STDIN is read until EOF, then the result is sent to the remote host.
# The remote script is then run, its STDOUT/ERR content and exit status are stored on the remote side.
# This data is then passed to the local side, after which it is passed to the caller.

# shellcheck disable=2016,2034
ssh::call() {
  local Ssh_Args=() # NOTE: strange transgressive variable

  local internal_args=()
  local keep_temp_files=false
  local terminal_mode=false

  while [[ "$#" -gt 0 ]]; do
    case $1 in
      -[46AaCfGgKkMNnqsTtVvXxYy]*)
        Ssh_Args+=("$1")
        shift
        ;;
      -[BbcDEeFIiJLlmOopQRSWw])
        Ssh_Args+=("$1" "$2")
        shift; shift
        ;;
      --keep-temp-files)
        internal_args+=("$1")
        keep_temp_files=true
        shift
        ;;
      --terminal)
        internal_args+=("$1")
        terminal_mode=true
        shift
        ;;
      --*)
        internal_args+=("$1")
        shift
        ;;
      -*)
        softfail "Unknown argument: $1" || return $?
        ;;
      *)
        break
        ;;
    esac
  done

  if [ "${keep_temp_files}" = false ] && [ "${REMOTE_KEEP_TEMP_FILES:-}" = true ]; then
    internal_args+=(--keep-temp-files)
    keep_temp_files=true
  fi

  # populate Ssh_Args array
  ssh::call::set_ssh_args || softfail "Unable to set ssh args" || return $?

  local temp_dir; temp_dir="$(mktemp -d)" || softfail "Unable to make temp file" || return $?

  ssh::call::internal --temp-dir "${temp_dir}" "${internal_args[@]}" "$@"
  
  local exit_status=$?

  # softfail --unless-good --exit-status "${exit_status}"

  if [ "${keep_temp_files}" != true ]; then
    local remove_list=("${temp_dir}/stdin" "${temp_dir}/stdout" "${temp_dir}/stderr")

    if [ "${exit_status}" = 0 ] || [ "${terminal_mode}" = true ]; then
      remove_list+=("${temp_dir}/script" "${temp_dir}")
    else
      echo "Script is kept due to abnormal termination: ${temp_dir}/script" >&2
    fi

    rm -fd "${remove_list[@]}" || softfail "Unable to remote temp files"
  fi

  return "${exit_status}"
}

ssh::call::internal() {
  local produce_script_args=()
  local direct_mode=false
  local terminal_mode=false
  local keep_temp_files=false
  local absorb_file
  local temp_dir
  local upload_path
  local ssh_destination

  while [[ "$#" -gt 0 ]]; do
    case $1 in
      --absorb)
        absorb_file="$2"
        shift; shift
        ;;
      --command|--cmd)
        produce_script_args+=(--command)
        shift
        ;;
      --home)
        produce_script_args+=(--home)
        shift
        ;;
      --direct)
        direct_mode=true
        shift
        ;;
      --terminal)
        produce_script_args+=(--terminal)
        terminal_mode=true
        shift
        ;;
      --keep-temp-files)
        keep_temp_files=true
        shift
        ;;
      --temp-dir)
        temp_dir="$2"
        shift; shift
        ;;
      --upload)
        upload_path="$2"
        shift; shift
        ;;
      -*)
        softfail "Unknown argument: $1" || return $?
        ;;
      *)
        break
        ;;
    esac
  done

  if [ -n "${REMOTE_HOST:-}" ]; then
    ssh_destination="${REMOTE_HOST}"
  else
    ssh_destination="$1"
    shift
  fi


  # upload files if needed
  local resolved_upload_path
  local rsync_ssh_args_string
  local upload_remote_temp
  local upload_rsync_dest
  local upload_rsync_src
  local upload_basename

  if [ -n "${upload_path:-}" ]; then

    if [ -d "${upload_path}" ]; then
      resolved_upload_path="$(cd "${upload_path}" >/dev/null 2>&1 && pwd)" || softfail "Unable to resolve upload directory: ${upload_path}" || return $?
      upload_basename="$(basename "${resolved_upload_path}")" || softfail || return $?

      if [ "${upload_basename}" = "/" ]; then
        upload_basename=root
      fi

      upload_rsync_src="${resolved_upload_path}/"
    else
      upload_basename="$(basename "${upload_path}")" || softfail || return $?
      upload_rsync_src="${upload_path}"
    fi

    upload_remote_temp="$(ssh "${Ssh_Args[@]}" "${ssh_destination}" "mktemp -d")" \
      || softfail --exit-status $? "Unable to create remote temp directory for file upload" || return $?

    upload_rsync_dest="${upload_remote_temp}/${upload_basename}"

    local ssh_args_item; for ssh_args_item in "${Ssh_Args[@]}"; do
      rsync_ssh_args_string+=" '$(<<<"${ssh_args_item}" sed -E "s/'/''/")'" || softfail || return $?
    done

    rsync \
      --rsh "ssh ${rsync_ssh_args_string:1}" \
      --checksum \
      --links \
      --perms \
      --recursive \
      --safe-links \
      --times \
      "${upload_rsync_src}" "${ssh_destination}:${upload_rsync_dest}" || softfail || return $?

    set -- "$@" "${upload_rsync_dest}"
 
  fi


  # produce script
  local script_checksum

  ssh::call::produce_script "${produce_script_args[@]}" "$@" >"${temp_dir}/script" || softfail "Unable to produce script" || return $?
  script_checksum="$(cksum <"${temp_dir}/script")" || softfail "Unable to calculate script checksum" || return $?


  # make upload script command
  local script_upload_command
  
  printf -v script_upload_command \
    'temp_dir="$(mktemp -d)" && cat>"${temp_dir}/script" && { if [ "$(cksum <"${temp_dir}/script")" != %q ]; then exit 254; fi; } && echo "${temp_dir}"' \
    "${script_checksum}" \
      || softfail || return $?


  # run upload script command
  local remote_temp_dir

  # shellcheck disable=2029
  remote_temp_dir="$(ssh "${Ssh_Args[@]}" "${ssh_destination}" "$(printf "sh -c %q" "${script_upload_command}")" <"${temp_dir}/script")" \
    || softfail --exit-status $? "Unable to upload script" || return $?

  if [ -z "${remote_temp_dir}" ]; then
    softfail "Unable to get remote temp file name" || return $?
  fi

  if [ "${terminal_mode}" = true ]; then
    ssh::call::invoke --terminal "${remote_temp_dir}" "${ssh_destination}" 'bash "${temp_dir}/script"'
    local task_status=$?

  elif [ "${direct_mode}" = true ]; then
    ssh::call::invoke "${remote_temp_dir}" "${ssh_destination}" 'bash "${temp_dir}/script"'
    local task_status=$?

  else
    # read local stdin and upload to remote
    local remote_stdin_file="/dev/null"
    if [ ! -t 0 ] || [ -n "${absorb_file:-}" ]; then
      if [ -n "${absorb_file:-}" ]; then
        mv "${absorb_file}" "${temp_dir}/stdin" || softfail "Unable to absorb file: ${absorb_file}" || return $?
      else
        cat >"${temp_dir}/stdin" || softfail "Unable to read stdin" || return $?
      fi

      if [ -s "${temp_dir}/stdin" ]; then
        local stdin_checksum

        stdin_checksum="$(cksum <"${temp_dir}/stdin")" || softfail "Unable to get stdin checksum" || return $?

        <"${temp_dir}/stdin" ssh::call::invoke "${remote_temp_dir}" "${ssh_destination}" \
          'cat >"${temp_dir}/stdin"; if [ "$(cksum <"${temp_dir}/stdin")" != %q ]; then exit 254; fi' "${stdin_checksum}" \
            || softfail --exit-status $? "Unable to store stdin data on remote" || return $?

        remote_stdin_file="${remote_temp_dir}/stdin"
      fi
    fi


    # run script
    ssh::call::invoke --nohup "${remote_temp_dir}" "${ssh_destination}" \
      'bash "${temp_dir}/script" <%q >"${temp_dir}/stdout" 2>"${temp_dir}/stderr"; script_status=$?; echo "${script_status}" >"${temp_dir}/exit_status"; touch "${temp_dir}/done"; exit "${script_status}"' \
      "${remote_stdin_file}"

    local task_status=$?

    local task_status_retrieved=false
    local stdout_retrieved=false
    local stderr_retrieved=false

    local call_result

    if [ "${task_status}" != 255 ]; then
      task_status_retrieved=true
    fi

    local started_at="${SECONDS}"
    local retry_limit="${REMOTE_RECONNECT_TIME_LIMIT:-600}"
    local first_run=true

    while true; do
      if [ "${first_run}" = true ]; then
        first_run=false
      else
        sleep "${REMOTE_RECONNECT_DELAY:-5}"

        if [ "$(( SECONDS - started_at ))" -ge "${retry_limit}" ]; then
          softfail "Unable to obtain task result, maximum time limit reached"
          return 1
        fi

        log::notice "Attempting to obtain result ($(( retry_limit - (SECONDS - started_at) )) second(s) till timeout)..." >&2
      fi

      # retrieve exit status
      if [ "${task_status_retrieved}" = false ]; then
        ssh::call::invoke "${remote_temp_dir}" "${ssh_destination}" 'test -f "${temp_dir}/done"'
        call_result=$?

        if [ "${call_result}" = 255 ]; then
          continue
        elif [ "${call_result}" != 0 ]; then

          # check if script is still around
          ssh::call::invoke "${remote_temp_dir}" "${ssh_destination}" 'test -d "${temp_dir}"'
          call_result=$?

          if [ "${call_result}" != 0 ] && [ "${call_result}" != 255 ]; then
            softfail "Unable to find remote task state directory, remote host may have been rebooted"
            return 1
          fi

          # check if script is started at all
          ssh::call::invoke "${remote_temp_dir}" "${ssh_destination}" 'test -f "${temp_dir}/stdout"'
          call_result=$?

          if [ "${call_result}" != 0 ] && [ "${call_result}" != 255 ]; then
            softfail "It seems that the remote command did not even start"
            return 1
          fi

          continue
        fi

        task_status="$(ssh::call::invoke "${remote_temp_dir}" "${ssh_destination}" 'cat "${temp_dir}/exit_status"')"
        call_result=$?

        if [ "${call_result}" = 255 ]; then
          continue
        elif [ "${call_result}" != 0 ]; then
          softfail "Unable to obtain exit status from remote"
          return 1
        fi

        if ! [[ "${task_status}" =~ ^[0-9]+$ ]]; then
          task_status=1
        fi

        task_status_retrieved=true
      fi

      # retrieve stdout
      if [ "${stdout_retrieved}" = false ]; then
        ssh::call::invoke "${remote_temp_dir}" "${ssh_destination}" 'cat "${temp_dir}/stdout"' >"${temp_dir}/stdout"
        call_result=$?

        if [ "${call_result}" = 255 ]; then
          continue
        elif [ "${call_result}" != 0 ]; then
          softfail "Unable to obtain stdout from remote"
          return 1
        fi

        stdout_retrieved=true
      fi

      # retrieve stderr
      if [ "${stderr_retrieved}" = false ]; then
        ssh::call::invoke "${remote_temp_dir}" "${ssh_destination}" 'cat "${temp_dir}/stderr"' >"${temp_dir}/stderr"
        call_result=$?

        if [ "${call_result}" = 255 ]; then
          continue
        elif [ "${call_result}" != 0 ]; then
          softfail "Unable to obtain stderr from remote"
          return 1
        fi

        stderr_retrieved=true
      fi

      # retrieve output checksum
      local remote_checksum
      local local_checksum

      # there is no PIPESTATUS in posix shell so output_concat_good flag file is used
      remote_checksum="$(ssh::call::invoke "${remote_temp_dir}" "${ssh_destination}" '{ cat "${temp_dir}/stdout" "${temp_dir}/stderr" && touch "${temp_dir}/output_concat_good"; } | cksum && test -f "${temp_dir}/output_concat_good"')"
      call_result=$?

      if [ "${call_result}" = 255 ]; then
        continue
      elif [ "${call_result}" != 0 ]; then
        softfail "Unable to obtain checksums from remote"
        return 1
      fi

      local_checksum="$(cat "${temp_dir}/stdout" "${temp_dir}/stderr" | cksum; test "${PIPESTATUS[*]}" = "0 0")" || softfail "Unable to get local output checksum" || return $?

      if [ "${remote_checksum}" != "${local_checksum}" ]; then
        softfail "Output checksum mismatch"
        return 1
      fi

      break
    done

    # display output
    local error_state=false

    if [ -s "${temp_dir}/stdout" ]; then
      cat "${temp_dir}/stdout" || { echo "Unable to display task stdout ($?)" >&2; error_state=true; }
    fi

    if [ -s "${temp_dir}/stderr" ]; then
      local terminal_sequence

      if [ -t 2 ] && terminal_sequence="$(tput setaf 1 2>/dev/null)"; then
        echo -n "${terminal_sequence}" >&2
      fi

      cat "${temp_dir}/stderr" >&2 || { echo "Unable to display task stderr ($?)" >&2; error_state=true; }

      if [ -t 2 ] && terminal_sequence="$(tput sgr 0 2>/dev/null)"; then
        echo -n "${terminal_sequence}" >&2
      fi
    fi

    if [ "${error_state}" = true ]; then
      softfail "Error reading STDOUT/STDERR in ssh::call"
      return 1
    fi
  fi

  # Note, that after that point we don't return any exit status other than task_status
  
  # remove remote temp files
  if [ "${keep_temp_files}" != true ]; then
    ssh::call::invoke "${remote_temp_dir}" "${ssh_destination}" 'rm -fd "${temp_dir}/script" "${temp_dir}/stdin" "${temp_dir}/stdout" "${temp_dir}/stderr" "${temp_dir}/output_concat_good" "${temp_dir}/exit_status" "${temp_dir}/done" "${temp_dir}"'
    softfail --unless-good --exit-status $? "Unable to remove remote temp files"

    if [ -n "${upload_remote_temp:-}" ]; then
      # shellcheck disable=2029
      ssh "${Ssh_Args[@]}" "${ssh_destination}" "$(printf "sh -c %q" "$(printf "rm -rf %q" "${upload_remote_temp}")")"
      softfail --unless-good --exit-status $? "Unable to remove remote temp directory for file upload"
    fi
  fi

  return "${task_status}"
}

ssh::call::set_ssh_args() {
  # Please note: Ssh_Args variable is not function-local for this function

  dir::should_exists --mode 0700 "${HOME}/.ssh" || softfail "Unable to create directory: ${HOME}/.ssh" || return $?
  dir::should_exists --mode 0700 "${HOME}/.ssh/control-sockets" || softfail "Unable to create directory: ${HOME}/.ssh/control-sockets" || return $?

  # shellcheck disable=2031
  if ! [[ "${OSTYPE}" =~ ^msys ]] && [ "${REMOTE_CONTROL_MASTER:-}" != "no" ]; then
    Ssh_Args+=("-o" "ControlMaster=${REMOTE_CONTROL_MASTER:-"auto"}")

    if [ "${REMOTE_FORWARD_AGENT:-}" = true ]; then
      Ssh_Args+=("-S" "${REMOTE_CONTROL_PATH:-"${HOME}/.ssh/control-sockets/%C.with-forward-agent"}")
    else
      Ssh_Args+=("-S" "${REMOTE_CONTROL_PATH:-"${HOME}/.ssh/control-sockets/%C"}")
    fi

    Ssh_Args+=("-o" "ControlPersist=${REMOTE_CONTROL_PERSIST:-"600"}")
  fi

  if [ "${REMOTE_FORWARD_AGENT:-}" = true ]; then
    Ssh_Args+=("-o" "ForwardAgent=yes")
  fi

  if [ -n "${REMOTE_IDENTITY_FILE:-}" ]; then
    Ssh_Args+=("-i" "${REMOTE_IDENTITY_FILE}")
  fi

  if [ -n "${REMOTE_PORT:-}" ]; then
    Ssh_Args+=("-p" "${REMOTE_PORT}")
  fi

  if [ "${REMOTE_SERVER_ALIVE_INTERVAL:-}" != "no" ]; then
    # the idea of 20 seconds is from https://datatracker.ietf.org/doc/html/rfc3948
    Ssh_Args+=("-o" "ServerAliveInterval=${REMOTE_SERVER_ALIVE_INTERVAL:-"20"}")
  fi

  if [ -n "${REMOTE_USER:-}" ]; then
    Ssh_Args+=("-l" "${REMOTE_USER}")
  fi

  # shellcheck disable=2031
  if declare -p REMOTE_SSH_ARGS >/dev/null 2>&1; then
    Ssh_Args=("${Ssh_Args[@]}" "${REMOTE_SSH_ARGS[@]}")
  fi
}

ssh::call::produce_script() {
  local command_mode=false
  local terminal_mode=false
  local cd_to_home=false

  while [[ "$#" -gt 0 ]]; do
    case $1 in
      --command)
        command_mode=true
        shift
        ;;
      --home)
        cd_to_home=true
        shift
        ;;
      --terminal)
        terminal_mode=true
        shift
        ;;
      -*)
        softfail "Unknown argument: $1" || return $?
        ;;
      *)
        break
        ;;
    esac
  done

  # test for empty command
  local joined_command="$*" # I don't want to save/restore IFS to be able to do "test -n "${*..."

  if [ -n "${joined_command//[[:blank:][:cntrl:]]/}" ]; then
    local command_present=true
  else
    local command_present=false
  fi

  if [ "${command_present}" = false ] && [ "${terminal_mode}" = false ]; then
    softfail "Command should be specified"
    return $?
  fi

  # shell options
  if shopt -o -q xtrace || [ "${RUNAG_VERBOSE:-}" = true ]; then
    echo "set -o xtrace"
  fi

  if shopt -o -q nounset; then
    echo "set -o nounset"
  fi

  # env list
  local env_list; IFS=" " read -r -a env_list <<<"${REMOTE_ENV:-} RUNAG_VERBOSE" || softfail || return $?

  local env_list_item; for env_list_item in "${env_list[@]}"; do
    if [ -n "${!env_list_item:-}" ]; then
      echo "export $(printf "%q=%q" "${env_list_item}" "${!env_list_item}")"
    fi
  done

  if [ "${command_mode}" = false ] && [ "${command_present}" = true ] && declare -F "$1" >/dev/null; then
    if [ -z "${PS1:-}" ]; then
      declare -f || softfail "Unable to produce source code dump of functions" || return $?
    else
      local function_name
      declare -F | while IFS="" read -r function_name; do
        if ! ssh::call::interactive_terminal_functions_filter "${function_name:11}"; then
          declare -f "${function_name:11}" || softfail "Unable to produce source code dump of function: ${function_name:11}" || return $?
        fi
      done
    fi
  fi

  if [ "${cd_to_home}" = true ]; then
    echo 'cd "${HOME}" || exit $?'
  fi

  if [ -n "${REMOTE_DIR:-}" ]; then
    printf "cd %q || exit \$?\n" "${REMOTE_DIR}"
  fi

  if [ -n "${REMOTE_UMASK:-}" ]; then
    printf "umask %q || exit \$?\n" "${REMOTE_UMASK}"
  fi

  if [ "${command_present}" = false ] && [ "${terminal_mode}" = true ]; then
    echo '"${SHELL}"'
  else
    local command_string; printf -v command_string " %q" "$@" || softfail "Unable to produce command string" || return $?
    echo "${command_string:1}"
  fi
}

ssh::call::interactive_terminal_functions_filter() {
  local function_name="$1"

  [ "${function_name:0:1}" = "_" ] ||
  [[ "${function_name}" =~ ^(asdf|command_not_found_handle|dequote|quote|quote_readline)$ ]]
}

ssh::call::invoke() {
  local nohup_mode=false
  local terminal_mode

  while [[ "$#" -gt 0 ]]; do
    case $1 in
      --nohup)
        nohup_mode=true
        shift
        ;;
      --terminal)
        terminal_mode=true
        shift
        ;;
      -*)
        softfail "Unknown argument: $1" || return $?
        ;;
      *)
        break
        ;;
    esac
  done

  local remote_temp_dir="$1"; shift
  local ssh_destination="$1"; shift
  local command_string="$1"; shift

  command_string="$(printf "temp_dir=%q; ${command_string}" "${remote_temp_dir}" "$@")"

  if [ "${nohup_mode}" = true ]; then
    # Keep an eye on bug #396 (sshd orphans processes when no pty allocated)
    # https://bugzilla.mindrot.org/show_bug.cgi?id=396
    command_string="$(printf "nohup sh -c %q >/dev/null 2>/dev/null </dev/null" "${command_string}")"
  fi

  # shellcheck disable=2029
  ssh ${terminal_mode:+"-t"} "${Ssh_Args[@]}" "${ssh_destination}" "$(printf "sh -c %q" "${command_string}")"
}

ssh::call::function_sources() {
  cat <<SHELL || softfail || return $?
$(declare -f ssh::call)
$(declare -f ssh::call::internal)
$(declare -f ssh::call::set_ssh_args)
$(declare -f ssh::call::produce_script)
$(declare -f ssh::call::interactive_terminal_functions_filter)
$(declare -f ssh::call::invoke)
SHELL
}
