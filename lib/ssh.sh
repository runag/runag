#!/usr/bin/env bash

#  Copyright 2012-2022 Stanislav Senotrusov <stan@senotrusov.com>
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

sshd::disable_password_authentication() {
  dir::sudo_make_if_not_exists /etc/ssh 755 || softfail || return $?
  dir::sudo_make_if_not_exists /etc/ssh/sshd_config.d 755 || softfail || return $?
  echo "PasswordAuthentication no" | file::sudo_write /etc/ssh/sshd_config.d/disable-password-authentication.conf || softfail || return $?
}

ssh::make_config_dir_if_not_exists() {
  dir::make_if_not_exists "${HOME}/.ssh" 0700 || softfail "Unable to create ssh user config directory" || return $?
}

ssh::make_control_sockets_dir_if_not_exists() {
  dir::make_if_not_exists "${HOME}/.ssh" 0700 || softfail "Unable to create ssh user config directory" || return $?
  dir::make_if_not_exists "${HOME}/.ssh/control-sockets" 0700 || softfail "Unable to create ssh control sockets directory" || return $?
}

ssh::make_keys_dir_if_not_exists() {
  dir::make_if_not_exists "${HOME}/.ssh" 0700 || softfail "Unable to create ssh user config directory" || return $?
  dir::make_if_not_exists "${HOME}/.ssh/keys" 0700 || softfail "Unable to create ssh keys directory" || return $?
}

ssh::make_config_d_dir_if_not_exists() {
  dir::make_if_not_exists "${HOME}/.ssh" 0700 || softfail "Unable to create ssh user config directory" || return $?
  dir::make_if_not_exists_and_set_permissions "${HOME}/.ssh/ssh_config.d" 0700 || softfail "Unable to create ssh user config.d directory" || return $?
}

ssh::add_ssh_config_d_include_directive() {
  ssh::make_config_d_dir_if_not_exists || softfail || return $?
  <<<"Include ~/.ssh/ssh_config.d/*.conf" file::update_block --mode 0600 "${HOME}/.ssh/config" "include files from ssh_config.d" || softfail "Unable to add configuration to user ssh config" || return $?
}

ssh::copy_authorized_keys_to_user() {
  local user_name="$1"

  local user_home; user_home="$(linux::get_user_home "${user_name}")" || softfail || return $?

  if [ ! -f "${user_home}/.ssh/authorized_keys" ]; then
    dir::sudo_make_if_not_exists "${user_home}/.ssh" 700 "${user_name}" "${user_name}" || softfail || return $?
    file::sudo_write "${user_home}/.ssh/authorized_keys" 600 "${user_name}" "${user_name}" <"${HOME}/.ssh/authorized_keys" || softfail || return $?
  fi
}

ssh::import_id() {
  local public_user_id="$1"
  local user_name="${2:-"${USER}"}"

  local user_home; user_home="$(linux::get_user_home "${user_name}")" || softfail || return $?
  local authorized_keys="${user_home}/.ssh/authorized_keys"

  if [ "${user_name}" != "${USER}" ]; then
    dir::sudo_make_if_not_exists "${user_home}/.ssh" 0700 "${user_name}" "${user_name}" || softfail || return $?
  else
    dir::make_if_not_exists "${user_home}/.ssh" 0700 || softfail || return $?
  fi

  ssh-import-id --output "${authorized_keys}" "${public_user_id}" || softfail || return $?

  if [ "${user_name}" != "${USER}" ]; then
    sudo chown "${user_name}"."${user_name}" "${authorized_keys}" || softfail || return $?
  fi
}

ssh::get_user_public_key() {
  local file_name="${1:-"id_ed25519"}"
  if [ -r "${HOME}/.ssh/${file_name}.pub" ]; then
    cat "${HOME}/.ssh/${file_name}.pub" || softfail || return $?
  else
    fail "Unable to find user public key"
  fi
}

ssh::install_ssh_profile_from_pass() {
  local profile_path="$1"
  local profile_name="$2"

  ssh::make_config_d_dir_if_not_exists || softfail || return $?
  ssh::make_keys_dir_if_not_exists || softfail || return $?

  local key_directory="${HOME}/.ssh/keys/${profile_name}"
  dir::make_if_not_exists "${key_directory}" 0700 || softfail || return $?

  # ssh key
  if pass::secret_exists "${profile_path}/id_ed25519"; then
    ssh::install_ssh_key_from_pass "${profile_path}/id_ed25519" "${key_directory}/id_ed25519" || softfail || return $?
  fi

  # ssh config
  local profile_config_path="${HOME}/.ssh/ssh_config.d/${profile_name}.conf"
  if pass::secret_exists "${profile_path}/config"; then
    pass::use --body "${profile_path}/config" file::write --mode 0600 "${profile_config_path}" || softfail || return $?
  else
    if pass::secret_exists "${profile_path}/id_ed25519"; then
      <<<"IdentityFile ${key_directory}/id_ed25519" file::write --mode 0600 "${profile_config_path}" || softfail || return $?
    fi
  fi

  # known hosts
  if pass::secret_exists "${profile_path}/known_hosts"; then
    pass::use --body "${profile_path}/known_hosts" file::update_block --mode 0600 "${HOME}/.ssh/known_hosts" "# ${profile_name}" || softfail || return $?
  fi
}

# ssh private key should be in body, password may be in password, separate .pub secret may contain public key in 1st line (password field)
ssh::install_ssh_key_from_pass() {
  local secret_path="$1"
  local key_file_path; key_file_path="${2:-"${HOME}/.ssh/$(basename "${secret_path}")"}" || softfail || return $?

  ssh::make_config_dir_if_not_exists || softfail || return $?
  pass::use --body "${secret_path}" file::write --mode 0600 "${key_file_path}" || softfail || return $?

  if pass::secret_exists "${secret_path}.pub"; then
    pass::use "${secret_path}.pub" file::write --mode 0600 "${key_file_path}.pub" || softfail || return $?
  fi

  if [[ "${OSTYPE}" =~ ^linux ]]; then
    pass::use --skip-if-empty "${secret_path}" ssh::gnome_keyring_credentials "${key_file_path}" || softfail || return $?
  elif [[ "${OSTYPE}" =~ ^darwin ]]; then
    pass::use --skip-if-empty "${secret_path}" ssh::macos_keychain "${key_file_path}" || softfail || return $?
  fi
}

ssh::gnome_keyring_credentials::exists() {
  local key_file_path="$1"

  secret-tool lookup unique "ssh-store:${key_file_path}" >/dev/null
}

ssh::gnome_keyring_credentials() {
  local key_file_path="$1"
  local password="$2"

  echo -n "${password}" | secret-tool store --label="Unlock password for: ${key_file_path}" unique "ssh-store:${key_file_path}"
  test "${PIPESTATUS[*]}" = "0 0" || softfail || return $?
}

ssh::macos_keychain::exists() {
  local key_file_path="$1"

  ssh-add -L | grep -qF "${key_file_path}"
}

ssh::macos_keychain() {
  local key_file_path="$1"
  local password="$2"

  local temp_file; temp_file="$(mktemp)" || softfail || return $?
  chmod 755 "${temp_file}" || softfail || return $?
  printf "#!/bin/sh\nexec cat\n" >"${temp_file}" || softfail || return $?

  echo "${password}" | SSH_ASKPASS="${temp_file}" DISPLAY=1 ssh-add -K "${key_file_path}"
  test "${PIPESTATUS[*]}" = "0 0" || softfail || return $?

  rm "${temp_file}" || softfail || return $?
}

ssh::macos_keychain::configure_use_on_all_hosts() {
  local ssh_config_file="${HOME}/.ssh/config"

  if [ ! -f "${ssh_config_file}" ]; then
    ( umask 0177 && touch "${ssh_config_file}" ) || softfail || return $?
  fi

  if ! grep -q "^# Use keychain" "${ssh_config_file}"; then
    tee -a "${ssh_config_file}" <<EOF || softfail "Unable to append to the file: ${ssh_config_file}" || return $?

# Use keychain
Host *
  UseKeychain yes
  AddKeysToAgent yes
EOF
  fi
}

ssh::wait_for_host_ssh_to_become_available() {
  local ip="$1"
  while true; do
    # note that here I omit "|| fail" for a reason, ssh-keyscan will fail if host is not yet there
    local key; key="$(ssh-keyscan "${ip}" 2>/dev/null)"
    if [ -n "${key}" ]; then
      return 0
    else
      if [ -t 2 ]; then
        echo "Waiting for SSH to become available on host '${ip}'..." >&2
      fi
      sleep 1 || softfail || return $?
    fi
  done
}

ssh::refresh_host_in_known_hosts() {
  local host_name="$1"
  ssh::remove_host_from_known_hosts "${host_name}" || softfail || return $?
  ssh::wait_for_host_ssh_to_become_available "${host_name}" || softfail || return $?
  ssh::add_host_to_known_hosts "${host_name}" || softfail || return $?
}

ssh::add_remote_to_known_hosts_and_then() {
  ssh::add_host_to_known_hosts || softfail || return $?
  "$@"
}

ssh::add_host_to_known_hosts() {
  local host_name="${1:-"${REMOTE_HOST}"}"
  local ssh_port="${2:-"${REMOTE_PORT:-"22"}"}"

  local known_hosts="${HOME}/.ssh/known_hosts"

  if ! command -v ssh-keygen >/dev/null; then
    fail "ssh-keygen not found"
  fi

  if [ ! -f "${known_hosts}" ]; then
    ssh::make_config_dir_if_not_exists || softfail || return $?
    ( umask 0177 && touch "${known_hosts}") || softfail || return $?
  fi

  if [ "${ssh_port}" = "22" ]; then
    local keygen_host_string="${host_name}"
  else
    local keygen_host_string="[${host_name}]:${ssh_port}"
  fi

  if ! ssh-keygen -F "${keygen_host_string}" >/dev/null; then
    ssh-keyscan -p "${ssh_port}" -T 30 "${host_name}" >> "${known_hosts}" || softfail "Unable to add host ${host_name}:${ssh_port} to ssh known_hosts" || return $?
  fi
}

ssh::remove_host_from_known_hosts() {
  local host_name="$1"
  ssh-keygen -R "${host_name}" || softfail || return $?
}

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

ssh::set_args() {
  # Please note: ssh_args variable is not function-local for this function

  ssh::make_control_sockets_dir_if_not_exists || softfail || return $?

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
  if shopt -o -q xtrace || [ "${SOPKA_VERBOSE:-}" = true ]; then
    echo "set -o xtrace"
  fi

  if shopt -o -q nounset; then
    echo "set -o nounset"
  fi
}

ssh::remote_env::base_list() {
  echo "SOPKA_UPDATE_SECRETS SOPKA_TASK_VERBOSE SOPKA_VERBOSE SOPKA_STDOUT_IS_TERMINAL SOPKA_STDERR_IS_TERMINAL"
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

ssh::script() {
  local joined_command="$*" # I don't want to save/restore IFS to be able to do "test -n "${*..."
  test -n "${joined_command//[[:blank:][:cntrl:]]/}" || softfail "Command should be specified" || return $?

  ssh::shell_options || softfail "Unable to produce shell-options" || return $?
  ssh::remote_env || softfail "Unable to produce remote-env" || return $?

  declare -f || softfail "Unable to produce source code dump of functions" || return $?

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

  if [ "${SOPKA_TASK_KEEP_TEMP_FILES:-}" != true ] && [ -n "${temp_dir:-}" ]; then
    rm -fd "${temp_dir}/script" "${temp_dir}/stdin" "${temp_dir}/stdout" "${temp_dir}/stderr" "${temp_dir}" || softfail "Unable to remote temp files" || return $?
  fi

  return "${exit_status}"
}

ssh::before-run() {
  # Please note: temp_dir, script_checksum, and remote_temp_dir variables are not function-local for this function

  if [ -z "${REMOTE_HOST:-}" ]; then
    softfail "REMOTE_HOST should be set" || return $?
  fi

  ssh::set_args || softfail "Unable to set ssh args" || return $?

  temp_dir="$(mktemp -d)" || softfail "Unable to make temp file" || return $?

  # shellcheck disable=2034
  if [ -t 1 ]; then
    local SOPKA_STDOUT_IS_TERMINAL=true
  fi

  # shellcheck disable=2034
  if [ -t 2 ]; then
    local SOPKA_STDERR_IS_TERMINAL=true
  fi

  ssh::script "$@" >"${temp_dir}/script" || softfail "Unable to produce script" || return $?

  script_checksum="$(cksum <"${temp_dir}/script")" || softfail "Unable to calculate script checksum" || return $?

  # shellcheck disable=2029,2016
  remote_temp_dir="$(ssh "${ssh_args[@]}" "${REMOTE_HOST}" "$(printf "sh -c %q" "$(printf 'temp_dir="$(mktemp -d)" && cat>"${temp_dir}/script" && { if [ "$(cksum <"${temp_dir}/script")" != %q ]; then exit 254; fi; } && echo "${temp_dir}"' "${script_checksum}")")" <"${temp_dir}/script")" || softfail "Unable to put script to remote" $? || return $?

  if [ -z "${remote_temp_dir}" ]; then
    softfail "Unable to get remote temp file name" || return $?
  fi
}

ssh::run() {
  local ssh_args=() temp_dir script_checksum remote_temp_dir

  ssh::before-run "$@" || softfail "Unable to perform ssh::before-run" $? || ssh::remove_temp_files $? || return $?

  # shellcheck disable=2029,2016
  ssh "${ssh_args[@]}" "${REMOTE_HOST}" "$(printf "sh -c %q" "$(printf 'temp_dir=%q; bash "${temp_dir}/script"; script_status=$?; rm -fd "${temp_dir}/script" "${temp_dir}"; exit "${script_status}"' "${remote_temp_dir}")")"

  local ssh_result=$?

  # On error here, we don't alter ssh command exit status
  ssh::remove_temp_files || softfail "Unable to remove temp files"

  return "${ssh_result}"
}

ssh::task_with_install_filter() {
  # shellcheck disable=2034
  local SOPKA_TASK_STDERR_FILTER=task::install_filter
  ssh::task "$@"
}

ssh::task_with_rubygems_fail_detector() {
  # shellcheck disable=2034
  local SOPKA_TASK_FAIL_DETECTOR=task::rubygems_fail_detector
  ssh::task "$@"
}

ssh::task_without_title() {
  # shellcheck disable=2034
  local SOPKA_TASK_OMIT_TITLE=true
  ssh::task "$@"
}

ssh::task_with_title() {
  # shellcheck disable=2034
  local SOPKA_TASK_TITLE="$1"
  ssh::task "${@:2}"
}

ssh::task_with_short_title() {
  # shellcheck disable=2034
  local SOPKA_TASK_TITLE="$1"
  ssh::task "$@"
}

ssh::task_verbose() {
  # shellcheck disable=2034
  local SOPKA_TASK_VERBOSE=true
  ssh::task "$@"
}

ssh::call() {
  # shellcheck disable=2034
  local SOPKA_TASK_VERBOSE=true SOPKA_TASK_OMIT_TITLE=true
  ssh::task "$@"
}

ssh::call_with_remote_temp_copy() {
  # shellcheck disable=2034
  local SOPKA_TASK_VERBOSE=true SOPKA_TASK_OMIT_TITLE=true
  ssh::task_with_remote_temp_copy "$@"
}

ssh::task_with_remote_temp_copy() {
  local local_dir="$1"

  if [ ! -e "${local_dir}" ]; then
    softfail "File does not exists: ${local_dir}"
    return $?
  fi

  if [ -d "${local_dir}" ]; then
    local rsync_src="${local_dir}/"
    local rsync_dest; rsync_dest="$(ssh::call mktemp -d)" || softfail "Unable to create remote temp directory" || return $?
  else
    local rsync_src="${local_dir}"
    local rsync_dest; rsync_dest="$(ssh::call mktemp)" || softfail "Unable to create remote temp file" || return $?
  fi

  rsync::sync_to_remote "${rsync_src}" "${rsync_dest}" || softfail "Unable to rsync to remote" || return $?

  ssh::task "$2" "${rsync_dest}" "${@:3}"
  local task_result=$?

  ssh::call rm -rf "${rsync_dest}" || softfail "Unable to remove remote temp file"

  return "${task_result}"
}

ssh::task::softfail() {
  # Please note: temp_dir and remote_temp_dir variables are not function-local for this function
  local message="$1"
  softfail "${message}${temp_dir:+". Local task: ${temp_dir}."}${remote_temp_dir:+". Remote task: ${remote_temp_dir}"}" "${@:2}"
}

ssh::task::invoke() {
  ssh::task::raw_invoke "$@" || ssh::task::softfail "ssh::task::raw_invoke call failed" $? || return $?
}

ssh::task::quiet_on_ssh_errors_invoke() {
  local error_message="$1"

  ssh::task::raw_invoke "${@:2}"

  local invoke_status=$?

  if [ "${invoke_status}" = 255 ]; then
    return 255
  fi

  if [ "${invoke_status}" != 0 ]; then
    ssh::task::softfail "${error_message}" "${invoke_status}"
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
    test -t 2 && terminal::color 12 >&2
    echo "${message}" >&2
    test -t 2 && terminal::default_color >&2
  fi
}

# shellcheck disable=2016
ssh::task() {
  local ssh_args=() temp_dir script_checksum remote_temp_dir information_message_state

  if [ "${SOPKA_TASK_OMIT_TITLE:-}" != true ]; then
    log::notice "Performing '${SOPKA_TASK_TITLE:-"$*"}'..." || ssh::task::softfail "Unable to display title" || return $?
  fi

  ssh::before-run "$@" || ssh::task::softfail "Unable to perform ssh::before-run" $? || ssh::remove_temp_files $? || return $?

  local remote_stdin="/dev/null"
  if [ ! -t 0 ]; then
    ssh::task::store_stdin || ssh::task::softfail "Unable to store stdin data" $? || ssh::remove_temp_files $? || return $?
  fi

  ssh::task::nohup_raw_invoke 'bash "${temp_dir}/script" <%q >"${temp_dir}/stdout" 2>"${temp_dir}/stderr"; script_status=$?; echo "${script_status}" >"${temp_dir}/exit_status"; touch "${temp_dir}/done"; exit "${script_status}"' "${remote_stdin}"
  local task_status=$?

  if [ "${task_status}" = 255 ]; then
    ssh::task::information_message "Got 255 as an exit status from local ssh command. That could be transport error or remote command may actually return 255. Will now attempt to reconnect to get a real remote command exit status and stdio streams..."
  fi

  local max_retries="${SOPKA_TASK_RECONNECT_ATTEMPTS:-120}"
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
    sleep "${SOPKA_TASK_RECONNECT_DELAY:-5}"
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

  task::detect_fail_state "${temp_dir}/stdout" "${temp_dir}/stderr" "${task_status}"
  task_status=$?

  task::complete || ssh::task::softfail "Unable to perform task::complete" || ssh::remove_temp_files $? || return $?

  # Note, that after that point we don't return any exit status other than task_status
  if [ "${SOPKA_TASK_KEEP_TEMP_FILES:-}" != true ]; then
    ssh::task::invoke 'rm -fd "${temp_dir}/script" "${temp_dir}/stdin" "${temp_dir}/stdout" "${temp_dir}/stderr" "${temp_dir}/output_concat_good" "${temp_dir}/exit_status" "${temp_dir}/done" "${temp_dir}"' || ssh::task::softfail "Unable to remove remote temp files"

    ssh::remove_temp_files || ssh::task::softfail "Unable to remove temp files"
  fi

  return "${task_status}"
}

# shellcheck disable=2016
ssh::task::store_stdin() {
  # Please note: temp_dir, remote_temp_dir, and remote_stdin variables are not function-local for this function

  cat >"${temp_dir}/stdin" || ssh::task::softfail "Unable to read stdin" || return $?

  if [ -s "${temp_dir}/stdin" ]; then
    local stdin_checksum; stdin_checksum="$(cksum <"${temp_dir}/stdin")" || ssh::task::softfail "Unable to get stdin checksum" || return $?

    ssh::task::invoke 'cat >"${temp_dir}/stdin"; if [ "$(cksum <"${temp_dir}/stdin")" != %q ]; then exit 254; fi' "${stdin_checksum}" <"${temp_dir}/stdin" || ssh::task::softfail "Unable to store stdin data on remote" $? || return $?

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
