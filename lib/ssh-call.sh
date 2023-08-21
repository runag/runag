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

# A set of functions to run bash scripts on a remote host.
#
# They serialize all functions defined in the current bash interpreter, and, along with a few
# selected environment variables, transfer them to a remote host to perform.
#
# ssh::run is a closest thing to a regular ssh. Standard streams are connected directly to a ssh process.
#
# ssh::call and ssh::task streams are buffered with the goal to make ssh calls resilent to network errors.
#
# First, the whole STDIN is read till the EOF, then the result is transfered to a remote host.
# Then remote script is started, STDOUT/ERR content and exit status are stored on remote side.
# Then they are transfered to a local side and then provided to a caller.
#
# ssh::call is similar to a regular ssh
#
# ssh::task will display a customisable task header and will hide stdout unless there is
# an non-zero exit status or there is something in the STDERR stream.
# A filter could be applied to a STDERR stream to account for the noisy processes.

# shellcheck disable=2030
ssh::with_forward_agent() {(
  if ! declare -p REMOTE_SSH_ARGS >/dev/null 2>&1; then
    REMOTE_SSH_ARGS=()
  fi

  REMOTE_SSH_ARGS+=("-o" "ForwardAgent=yes")
  REMOTE_CONTROL_PATH="${HOME}/.ssh/control-socket.with-forward-agent.%C"
  "$@"
)}

ssh::without_control_master() {
  REMOTE_CONTROL_MASTER=no "$@"
}

# shellcheck disable=2030,2031
ssh::with_ssh_args() {(
  if ! declare -p REMOTE_SSH_ARGS >/dev/null 2>&1; then
    REMOTE_SSH_ARGS=()
  fi

  local item; for item in "$@"; do
    if [ "${item}" = "--" ]; then
      shift
      break
    fi
    REMOTE_SSH_ARGS+=("${item}")
    shift
  done

  "$@"
)}

ssh::set_ssh_args() {
  # Please note: ssh_args variable is not function-local for this function

  dir::should_exists --mode 0700 "${HOME}/.ssh" || softfail "Unable to create ssh user config directory" || return $?
  dir::should_exists --mode 0700 "${HOME}/.ssh/control-sockets" || softfail "Unable to create ssh control sockets directory" || return $?

  # shellcheck disable=2031
  if ! [[ "${OSTYPE}" =~ ^msys ]] && [ "${REMOTE_CONTROL_MASTER:-}" != "no" ]; then
    ssh_args+=("-o" "ControlMaster=${REMOTE_CONTROL_MASTER:-"auto"}")
    ssh_args+=("-S" "${REMOTE_CONTROL_PATH:-"${HOME}/.ssh/control-sockets/%C"}")
    ssh_args+=("-o" "ControlPersist=${REMOTE_CONTROL_PERSIST:-"600"}")
  fi

  if [ -n "${REMOTE_IDENTITY_FILE:-}" ]; then
    ssh_args+=("-i" "${REMOTE_IDENTITY_FILE}")
  fi

  if [ -n "${REMOTE_PORT:-}" ]; then
    ssh_args+=("-p" "${REMOTE_PORT}")
  fi

  if [ "${REMOTE_SERVER_ALIVE_INTERVAL:-}" != "no" ]; then
    # the idea of 20 seconds is from https://datatracker.ietf.org/doc/html/rfc3948
    ssh_args+=("-o" "ServerAliveInterval=${REMOTE_SERVER_ALIVE_INTERVAL:-"20"}")
  fi

  if [ -n "${REMOTE_USER:-}" ]; then
    ssh_args+=("-l" "${REMOTE_USER}")
  fi

  # shellcheck disable=2031
  if declare -p REMOTE_SSH_ARGS >/dev/null 2>&1; then
    ssh_args=("${ssh_args[@]}" "${REMOTE_SSH_ARGS[@]}")
  fi
}

ssh::shell_options() {
  if shopt -o -q xtrace || [ "${RUNAG_VERBOSE:-}" = true ]; then
    echo "set -o xtrace"
  fi

  if shopt -o -q nounset; then
    echo "set -o nounset"
  fi
}

ssh::remote_env::base_list() {
  echo "RUNAG_UPDATE_SECRETS RUNAG_TASK_VERBOSE RUNAG_VERBOSE RUNAG_STDOUT_IS_TERMINAL RUNAG_STDERR_IS_TERMINAL"
}

ssh::remote_env() {
  local base_list; base_list="$(ssh::remote_env::base_list)" || softfail || return $?

  local list; IFS=" " read -r -a list <<< "${REMOTE_ENV:-} ${base_list}" || softfail || return $?

  local item; for item in "${list[@]}"; do
    if [ -n "${!item:-}" ]; then
      echo "export $(printf "%q=%q" "${item}" "${!item}")"
    fi
  done
}

ssh::script::interactive_terminal_functions_filter() {
  local function_name="$1"

  [ "${function_name:0:1}" = "_" ] ||
  [[ "${function_name}" =~ ^(asdf|command_not_found_handle|dequote|quote|quote_readline)$ ]]
}

ssh::script() {
  local joined_command="$*" # I don't want to save/restore IFS to be able to do "test -n "${*..."
  test -n "${joined_command//[[:blank:][:cntrl:]]/}" || softfail "Command should be specified" || return $?

  ssh::shell_options || softfail "Unable to produce shell-options" || return $?
  ssh::remote_env || softfail "Unable to produce remote-env" || return $?

  if [ -z "${PS1:-}" ]; then
    declare -f || softfail "Unable to produce source code dump of functions" || return $?
  else
    local function_name
    declare -F | while IFS="" read -r function_name; do
      if ! ssh::script::interactive_terminal_functions_filter "${function_name:11}"; then
        declare -f "${function_name:11}" || softfail "Unable to produce source code dump of function: ${function_name:11}" || return $?
      fi
    done
  fi

  if [ -n "${REMOTE_DIR:-}" ]; then
    printf "cd %q || exit \$?\n" "${REMOTE_DIR}"
  fi

  if [ -n "${REMOTE_UMASK:-}" ]; then
    printf "umask %q || exit \$?\n" "${REMOTE_UMASK}"
  fi

  local command_string; printf -v command_string " %q" "$@" || softfail "Unable to produce command string" || return $?
  echo "${command_string:1}"
}

ssh::remove_temp_files() {
  local exit_status="${1:-0}"

  if [ "${RUNAG_TASK_KEEP_TEMP_FILES:-}" != true ]; then
    if [ -n "${temp_dir:-}" ]; then
      rm -fd "${temp_dir}/script" "${temp_dir}/stdin" "${temp_dir}/stdout" "${temp_dir}/stderr" "${temp_dir}" || softfail "Unable to remote temp files" || return $?
    fi

    if [ -n "${push_files}" ]; then
      ssh::call rm -rf "${push_files_rsync_dest}" || softfail "Unable to remove remote temp file"
    fi
  fi

  return "${exit_status}"
}

ssh::upload_script() {
  # Please note: temp_dir, script_checksum, and remote_temp_dir variables are not function-local for this function

  if [ -z "${REMOTE_HOST:-}" ]; then
    softfail "REMOTE_HOST should be set" || return $?
  fi

  ssh::set_ssh_args || softfail "Unable to set ssh args" || return $?

  temp_dir="$(mktemp -d)" || softfail "Unable to make temp file" || return $?

  # shellcheck disable=2034
  if [ -t 1 ]; then
    local RUNAG_STDOUT_IS_TERMINAL=true
  fi

  # shellcheck disable=2034
  if [ -t 2 ]; then
    local RUNAG_STDERR_IS_TERMINAL=true
  fi

  ssh::script "$@" >"${temp_dir}/script" || softfail "Unable to produce script" || return $?

  script_checksum="$(cksum <"${temp_dir}/script")" || softfail "Unable to calculate script checksum" || return $?

  # shellcheck disable=2029,2016
  remote_temp_dir="$(ssh "${ssh_args[@]}" "${REMOTE_HOST}" "$(printf "sh -c %q" "$(printf 'temp_dir="$(mktemp -d)" && cat>"${temp_dir}/script" && { if [ "$(cksum <"${temp_dir}/script")" != %q ]; then exit 254; fi; } && echo "${temp_dir}"' "${script_checksum}")")" <"${temp_dir}/script")" || softfail --exit-status $? "Unable to put script to remote" || return $?

  if [ -z "${remote_temp_dir}" ]; then
    softfail "Unable to get remote temp file name" || return $?
  fi
}

ssh::run() {
  local ssh_args=() temp_dir script_checksum remote_temp_dir

  ssh::upload_script "$@" || softfail --exit-status $? "Unable to perform ssh::before-run" || ssh::remove_temp_files $? || return $?

  if [ "${RUNAG_TASK_KEEP_TEMP_FILES:-}" != true ]; then
    # shellcheck disable=2016
    local temp_file_cleanup_command='rm -fd "${temp_dir}/script" "${temp_dir}";'
  else
    local temp_file_cleanup_command=''
  fi

  # shellcheck disable=2029,2016
  ssh "${ssh_args[@]}" "${REMOTE_HOST}" "$(printf "sh -c %q" "$(printf 'temp_dir=%q; bash "${temp_dir}/script"; script_status=$?; %s exit "${script_status}"' "${remote_temp_dir}" "${temp_file_cleanup_command}")")"

  local ssh_result=$?

  # On error here, we don't alter ssh command exit status
  ssh::remove_temp_files || softfail "Unable to remove temp files"

  return "${ssh_result}"
}

ssh::call() {
  # shellcheck disable=2034
  local RUNAG_TASK_VERBOSE=true RUNAG_TASK_OMIT_TITLE=true
  ssh::task "$@"
}

ssh::task::softfail() {
  local exit_status=""
  local unless_good=""
  local message=""

  while [[ "$#" -gt 0 ]]; do
    case $1 in
    -e|--exit-status)
      exit_status="$2"
      shift; shift
      ;;
    -u|--unless-good)
      unless_good=true
      shift
      ;;
    -*)
      { declare -f "log::error" >/dev/null && log::error "Unknown argument for ssh::task::softfail: $1"; } || echo "Unknown argument for ssh::task::softfail: $1" >&2
      shift
      message="$*"
      break
      ;;
    *)
      message="$1"
      break
      ;;
    esac
  done

  if [ -z "${message}" ]; then
    message="Abnormal termination"
  fi

  # Please note: temp_dir and remote_temp_dir variables are not function-local for this function
  softfail ${exit_status:+--exit-status "${exit_status}"} ${unless_good:+--unless-good} "${message}${temp_dir:+" (local task: ${temp_dir})"}${remote_temp_dir:+" (remote task: ${remote_temp_dir})"}"
}

ssh::task::invoke() {
  ssh::task::raw_invoke "$@" || ssh::task::softfail --exit-status $? "ssh::task::raw_invoke call failed" || return $?
}

ssh::task::quiet_on_ssh_errors_invoke() {
  local error_message="$1"

  ssh::task::raw_invoke "${@:2}"

  local invoke_status=$?

  if [ "${invoke_status}" = 255 ]; then
    return 255
  fi

  if [ "${invoke_status}" != 0 ]; then
    ssh::task::softfail --exit-status "${invoke_status}" "${error_message}"
    return "${invoke_status}"
  fi
}

ssh::task::raw_invoke() {
  # Please note: remote_temp_dir variable is not function-local for this function
  # shellcheck disable=2029
  ssh "${ssh_args[@]}" "${REMOTE_HOST}" "$(printf "sh -c %q" "$(printf "temp_dir=%q; $1" "${remote_temp_dir}" "${@:2}")")"
}

ssh::task::nohup_raw_invoke() {
  # Keep an eye on this
  # Bug 396 - sshd orphans processes when no pty allocated
  # https://bugzilla.mindrot.org/show_bug.cgi?id=396

  # shellcheck disable=2029
  ssh "${ssh_args[@]}" "${REMOTE_HOST}" "$(printf "sh -c %q" "$(printf "nohup sh -c %q >/dev/null 2>/dev/null </dev/null" "$(printf "temp_dir=%q; $1" "${remote_temp_dir}" "${@:2}")")")"
}

ssh::task::information_message() {
  local message="$1"
  if [ -t 2 ]; then
    local color_sequence; color_sequence="$(tput setaf 12 2>/dev/null)" || color_sequence=""
    local reset_attrs; reset_attrs="$(tput sgr 0 2>/dev/null)" || reset_attrs=""

    echo "${color_sequence}${message}${reset_attrs}" >&2
  fi
}

# shellcheck disable=2016,2034
ssh::task() {
  local short_title=false
  local task_title=""
  local push_files="" push_files_rsync_src="" push_files_rsync_dest=""

  while [[ "$#" -gt 0 ]]; do
    case $1 in
    -e|--stderr-filter)
      local RUNAG_TASK_STDERR_FILTER="$2"
      shift; shift
      ;;
    -i|--install-filter)
      local RUNAG_TASK_STDERR_FILTER=task::install_filter
      shift
      ;;
    -f|--fail-detector)
      local RUNAG_TASK_FAIL_DETECTOR="$2"
      shift; shift
      ;;
    -r|--rubygems-fail-detector)
      local RUNAG_TASK_FAIL_DETECTOR=task::rubygems_fail_detector
      shift
      ;;
    -t|--title)
      task_title="$2"
      shift; shift
      ;;
    -s|--short-title)
      short_title=true
      shift
      ;;
    -o|--omit-title)
      local RUNAG_TASK_OMIT_TITLE=true
      shift
      ;;
    -p|--push-files)
      local push_files="$2"
      shift; shift
      ;;
    -k|--keep-temp-files)
      local RUNAG_TASK_KEEP_TEMP_FILES=true
      shift
      ;;
    -v|--verbose)
      local RUNAG_TASK_VERBOSE=true
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

  if [ "${RUNAG_TASK_OMIT_TITLE:-}" != true ]; then
    if [ "${short_title}" = true ]; then
      task_title="$1"
    fi
    log::notice "Performing '${task_title:-"$*"}'..." || softfail "Unable to display title" || return $?
  fi

  if [ -n "${push_files}" ]; then
    if [ ! -e "${push_files}" ]; then
      softfail "File or directory does not exists: ${push_files}"
      return $?
    fi

    if [ -d "${push_files}" ]; then
      push_files_rsync_src="${push_files}/"
      push_files_rsync_dest="$(ssh::call mktemp -d)" || softfail "Unable to create remote temp directory" || return $?
    else
      push_files_rsync_src="${push_files}"
      push_files_rsync_dest="$(ssh::call mktemp)" || softfail "Unable to create remote temp file" || return $?
    fi

    rsync::sync_to_remote "${push_files_rsync_src}" "${push_files_rsync_dest}" || softfail "Unable to rsync to remote" || return $?
    set -- "$@" "${push_files_rsync_dest}"
  fi

  local ssh_args=() temp_dir script_checksum remote_temp_dir information_message_state

  ssh::upload_script "$@" || ssh::task::softfail --exit-status $? "Unable to perform ssh::before-run" || ssh::remove_temp_files $? || return $?

  local remote_stdin="/dev/null"
  if [ ! -t 0 ]; then
    ssh::task::upload_stdin || ssh::task::softfail --exit-status $? "Unable to store stdin data" || ssh::remove_temp_files $? || return $?
  fi

  ssh::task::nohup_raw_invoke 'bash "${temp_dir}/script" <%q >"${temp_dir}/stdout" 2>"${temp_dir}/stderr"; script_status=$?; echo "${script_status}" >"${temp_dir}/exit_status"; touch "${temp_dir}/done"; exit "${script_status}"' "${remote_stdin}"
  local task_status=$?

  if [ "${task_status}" = 255 ]; then
    ssh::task::information_message "Got 255 as an exit status from local ssh command. That could be transport error or remote command may actually return 255. Will now attempt to reconnect to get a real remote command exit status and stdio streams..."
  fi

  local max_retries="${RUNAG_TASK_RECONNECT_ATTEMPTS:-120}"
  local i; for ((i=1; i<=max_retries; i++)); do

    ssh::task::get_result

    local get_result_result=$?
    if [ "${get_result_result}" != 255 ]; then
      break
    fi

    if [ "${information_message_state}" = done_flag_absent ]; then
      ssh::task::information_message "Command is probably still running, retrying (${i} of ${max_retries})..."
    else
      ssh::task::information_message "Transport error getting the command result, retrying (${i} of ${max_retries})..."
    fi

    information_message_state=clean_state
    sleep "${RUNAG_TASK_RECONNECT_DELAY:-5}"
  done

  if [ "${get_result_result}" = 255 ]; then
    ssh::task::softfail "Maximum retry limit reached getting the task result back"
    ssh::remove_temp_files || softfail "Unable to remove temp files"
    return "${get_result_result}"
  fi

  if [ "${get_result_result}" != 0 ]; then
    ssh::task::softfail "Unable to get task result"
    ssh::remove_temp_files || softfail "Unable to remove temp files"
    return "${get_result_result}"
  fi

  local error_state=false

  if [ -s "${temp_dir}/stdout" ]; then
    cat "${temp_dir}/stdout" || { echo "Unable to display task stdout ($?)" >&2; error_state=true; }
  fi

  if [ -s "${temp_dir}/stderr" ]; then
    local terminal_sequence

    if [ -t 2 ] && terminal_sequence="$(tput setaf 9 2>/dev/null)"; then
      echo -n "${terminal_sequence}" >&2
    fi

    cat "${temp_dir}/stderr" >&2 || { echo "Unable to display task stderr ($?)" >&2; error_state=true; }

    if [ -t 2 ] && terminal_sequence="$(tput sgr 0 2>/dev/null)"; then
      echo -n "${terminal_sequence}" >&2
    fi
  fi

  if [ "${error_state}" = true ]; then
    ssh::task::softfail "Error reading STDOUT/STDERR in ssh::call" || ssh::remove_temp_files $? || return $?
  fi

  # Note, that after that point we don't return any exit status other than task_status
  
  if [ "${RUNAG_TASK_KEEP_TEMP_FILES:-}" != true ]; then
    ssh::task::invoke 'rm -fd "${temp_dir}/script" "${temp_dir}/stdin" "${temp_dir}/stdout" "${temp_dir}/stderr" "${temp_dir}/output_concat_good" "${temp_dir}/exit_status" "${temp_dir}/done" "${temp_dir}"' || ssh::task::softfail "Unable to remove remote temp files"

    ssh::remove_temp_files || ssh::task::softfail "Unable to remove temp files"
  fi

  return "${task_status}"
}

# shellcheck disable=2016
ssh::task::upload_stdin() {
  # Please note: temp_dir, remote_temp_dir, and remote_stdin variables are not function-local for this function

  cat >"${temp_dir}/stdin" || ssh::task::softfail "Unable to read stdin" || return $?

  if [ -s "${temp_dir}/stdin" ]; then
    local stdin_checksum; stdin_checksum="$(cksum <"${temp_dir}/stdin")" || ssh::task::softfail "Unable to get stdin checksum" || return $?

    ssh::task::invoke 'cat >"${temp_dir}/stdin"; if [ "$(cksum <"${temp_dir}/stdin")" != %q ]; then exit 254; fi' "${stdin_checksum}" <"${temp_dir}/stdin" || ssh::task::softfail --exit-status $? "Unable to store stdin data on remote" || return $?

    remote_stdin="${remote_temp_dir}/stdin"
  fi
}

# shellcheck disable=2016
ssh::task::get_result() {
  # Please note: task_status and temp_dir variables are not function-local for this function

  if [ "${task_status}" = 255 ]; then
    if ! ssh::task::raw_invoke 'test -f "${temp_dir}/done"'; then
      information_message_state=done_flag_absent

      ssh::task::quiet_on_ssh_errors_invoke "Unable to find remote task state directory, remote host may have been rebooted" 'test -d "${temp_dir}"' || return $?
      ssh::task::quiet_on_ssh_errors_invoke "It seems that the remote command did not even start" 'test -f "${temp_dir}/stdout"' || return $?

      return 255
    fi

    local retrieved_task_status
    retrieved_task_status="$(ssh::task::quiet_on_ssh_errors_invoke "Unable to get exit status from remote" 'cat "${temp_dir}/exit_status"')" || return $?

    if [[ "${retrieved_task_status}" =~ ^[0-9]+$ ]]; then
      task_status="${retrieved_task_status}"
    else
      task_status=1
    fi
  fi

  ssh::task::quiet_on_ssh_errors_invoke "Unable to get stdout from remote" 'cat "${temp_dir}/stdout"' >"${temp_dir}/stdout" || return $?
  ssh::task::quiet_on_ssh_errors_invoke "Unable to get stderr from remote" 'cat "${temp_dir}/stderr"' >"${temp_dir}/stderr" || return $?

  local remote_checksum local_checksum

  # there is no PIPESTATUS in posix shell
  remote_checksum="$(ssh::task::quiet_on_ssh_errors_invoke "Unable to get remote output checksum" '{ cat "${temp_dir}/stdout" "${temp_dir}/stderr" && touch "${temp_dir}/output_concat_good"; } | cksum && test -f "${temp_dir}/output_concat_good"')" || return $?

  local_checksum="$(cat "${temp_dir}/stdout" "${temp_dir}/stderr" | cksum; test "${PIPESTATUS[*]}" = "0 0")" || ssh::task::softfail "Unable to get local output checksum" || return $?

  if [ "${remote_checksum}" != "${local_checksum}" ]; then
    ssh::task::softfail "Output checksum mismatch"
    return 1
  fi
}
