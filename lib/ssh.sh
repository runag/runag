#!/usr/bin/env bash

#  Copyright 2012-2024 Rùnag project contributors
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
  dir::should_exists --sudo --mode 0755 /etc/ssh  || softfail || return $?
  dir::should_exists --sudo --mode 0755 /etc/ssh/sshd_config.d || softfail || return $?

  <<<"PasswordAuthentication no" file::write --sudo --mode 0644 /etc/ssh/sshd_config.d/disable-password-authentication.conf || softfail || return $?
}

ssh::add_ssh_config_d_include_directive() {
  dir::should_exists --mode 0700 "${HOME}/.ssh" || softfail "Unable to create ssh user config directory" || return $?
  dir::should_exists --mode 0700 "${HOME}/.ssh/ssh_config.d" || softfail "Unable to create ssh user config.d directory" || return $?

  # The "Host *" here is for the case if there are any "Host" directives in .ssh/config,
  # as the last of "Host" will catch this "Include" in their scope
  #
  # Note that the scope of any "Host" directives in *.conf files are contained within their respective files

  printf "Host *\nInclude ~/.ssh/ssh_config.d/*.conf\n" | file::write_block --mode 0600 "${HOME}/.ssh/config" "include-files-from-ssh-config-d" || softfail "Unable to add configuration to user ssh config" || return $?
}

ssh::install_authorized_keys_from_pass() {
  local profile_name
  local file_owner
  local file_group
  local perhaps_sudo
  local ssh_call
  local ssh_call_prefix

  while [ "$#" -gt 0 ]; do
    case "$1" in
      -p|--profile-name)
        profile_name="$2"
        shift; shift
        ;;
      -o|--owner)
        file_owner="$2"
        shift; shift
        ;;
      -g|--group)
        file_group="$2"
        shift; shift
        ;;
      -s|--sudo)
        perhaps_sudo=true
        shift
        ;;
      -c|--ssh-call)
        ssh_call=true
        ssh_call_prefix="ssh::call"
        shift
        ;;
      -w|--ssh-call-with)
        ssh_call=true
        ssh_call_prefix="$2"
        shift; shift
        ;;
      -*)
        fail "Unknown argument: $1"
        ;;
      *)
        break
        ;;
    esac
  done

  local profile_path="$1"

  if [ -z "${profile_name:-}" ]; then
    profile_name="$(basename "${profile_path}")" || softfail || return $?
  fi

  local home_dir
  
  if [ -n "${file_owner:-}" ]; then
    home_dir="$(${ssh_call:+"${ssh_call_prefix}"} linux::get_home_dir "${file_owner}")" || softfail || return $?

  elif [ "${ssh_call:-}" != true ]; then
    home_dir="${HOME}"
  fi

  ${ssh_call:+"${ssh_call_prefix}"} dir::should_exists ${perhaps_sudo:+"--sudo"}  --mode 0700 ${file_owner:+"--owner" "${file_owner}"} ${file_group:+"--group" "${file_group}"} "${home_dir:+"${home_dir}/"}.ssh" || softfail "Unable to create ssh user config directory" || return $?

  # id_ed25519.pub
  if pass::secret_exists "${profile_path}/id_ed25519.pub"; then
    pass::use --absorb-in-callback "${profile_path}/id_ed25519.pub" ${ssh_call:+"${ssh_call_prefix}"} file::write_block ${perhaps_sudo:+"--sudo"} --mode 0600 ${file_owner:+"--owner" "${file_owner}"} ${file_group:+"--group" "${file_group}"} "${home_dir:+"${home_dir}/"}.ssh/authorized_keys" "${profile_name}-id_ed25519.pub" || softfail || return $?
  fi

  # authorized_keys
  if pass::secret_exists "${profile_path}/authorized_keys"; then
    pass::use --absorb-in-callback --body "${profile_path}/authorized_keys" ${ssh_call:+"${ssh_call_prefix}"} file::write_block ${perhaps_sudo:+"--sudo"} --mode 0600 ${file_owner:+"--owner" "${file_owner}"} ${file_group:+"--group" "${file_group}"} "${home_dir:+"${home_dir}/"}.ssh/authorized_keys" "${profile_name}-authorized_keys" || softfail || return $?
  fi
}

ssh::install_ssh_profile_from_pass() {
  local profile_name

  while [ "$#" -gt 0 ]; do
    case "$1" in
      -p|--profile-name)
        profile_name="$2"
        shift; shift
        ;;
      -*)
        fail "Unknown argument: $1"
        ;;
      *)
        break
        ;;
    esac
  done

  local profile_path="$1"

  # ssh key
  if pass::secret_exists "${profile_path}/id_ed25519"; then
    # I have trouble getting Ubuntu desktop 22.04 to remember password for the key if that key resides in any subdirectory inside ~/.ssh
    # If I put the key right into ~/.ssh then it's fine
    ssh::install_ssh_key_from_pass "${profile_path}/id_ed25519" "${HOME}/.ssh/${profile_name}.id_ed25519" || softfail || return $?
  fi

  # ssh config
  local config_file_path="${HOME}/.ssh/ssh_config.d/${profile_name}.conf"

  if [[ "${OSTYPE}" =~ ^linux ]] && pass::secret_exists "${profile_path}/config.linux"; then
    ssh::install_ssh_profile_from_pass::write_config  "${profile_path}" "${profile_name}" "${config_file_path}" "${profile_path}/config.linux" || softfail || return $?

  elif pass::secret_exists "${profile_path}/config"; then
    ssh::install_ssh_profile_from_pass::write_config  "${profile_path}" "${profile_name}" "${config_file_path}" "${profile_path}/config" || softfail || return $?
    
  elif pass::secret_exists "${profile_path}/id_ed25519"; then
    <<<"IdentityFile ${HOME}/.ssh/${profile_name}.id_ed25519" file::write --mode 0600 "${config_file_path}" || softfail || return $?
  fi

  # known hosts
  if pass::secret_exists "${profile_path}/known_hosts"; then
    pass::use --absorb-in-callback --body "${profile_path}/known_hosts" file::write_block --mode 0600 "${HOME}/.ssh/known_hosts" "${profile_name}" || softfail || return $?
  fi
}

ssh::install_ssh_profile_from_pass::write_config() {
  local profile_path="$1"
  local profile_name="$2"
  local config_file_path="$3"
  local pass_config_path="$4"
  
  local temp_file; temp_file="$(mktemp)" || softfail || return $?

  pass::use --absorb-in-callback --body "${pass_config_path}" file::write --mode 0600 "${temp_file}" || softfail || return $?

  if pass::secret_exists "${profile_path}/id_ed25519"; then
    sed --in-place -E "s#IdentityFile %k#IdentityFile ${HOME}/.ssh/${profile_name}.id_ed25519#g" "${temp_file}" || softfail || return $?
  fi

  file::write --absorb "${temp_file}" --mode 0600 "${config_file_path}" || softfail || return $?
}

# ssh private key should be in body, password may be in password, optional .pub secret can contain public key in 1st line (password field)
ssh::install_ssh_key_from_pass() {
  local secret_path="$1"
  local key_file_path; key_file_path="${2:-"${HOME}/.ssh/$(basename "${secret_path}")"}" || softfail || return $?

  dir::should_exists --mode 0700 "${HOME}/.ssh" || softfail "Unable to create ssh user config directory" || return $?

  pass::use --absorb-in-callback --body "${secret_path}" file::write --mode 0600 "${key_file_path}" || softfail || return $?

  if pass::secret_exists "${secret_path}.pub"; then
    pass::use "${secret_path}.pub" file::write --mode 0600 "${key_file_path}.pub" || softfail || return $?
  fi

  if [[ "${OSTYPE}" =~ ^linux ]]; then
    pass::use --skip-if-empty "${secret_path}" ssh::gnome_keyring_credentials "${key_file_path}" || softfail || return $?
  elif [[ "${OSTYPE}" =~ ^darwin ]]; then
    pass::use --skip-if-empty "${secret_path}" ssh::macos_keychain "${key_file_path}" || softfail || return $?
  fi
}

ssh::install_ssh_key_from_pass_to_remote() {
  local pass_args=()

  while [ "$#" -gt 0 ]; do
    case "$1" in
      -*)
        pass_args+=("$1")
        shift
        ;;
      *)
        break
        ;;
    esac
  done

  local secret_path="$1"
  local key_file_path; key_file_path="${2:-".ssh/$(basename "${secret_path}")"}" || softfail || return $?

  ssh::call --home dir::should_exists --mode 0700 ".ssh" || softfail "Unable to create ssh user config directory" || return $?

  pass::use "${pass_args[@]}" --absorb-in-callback --body "${secret_path}" ssh::call --home file::write --mode 0600 "${key_file_path}" || softfail || return $?

  if pass::secret_exists "${secret_path}.pub"; then
    pass::use "${pass_args[@]}" "${secret_path}.pub" ssh::call --home file::write --mode 0600 "${key_file_path}.pub" || softfail || return $?
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

ssh::refresh_host_in_known_hosts() {
  local ssh_port="${REMOTE_PORT:-"22"}"

  while [ "$#" -gt 0 ]; do
    case "$1" in
      -p|--port)
        ssh_port="$2"
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

  local host_name="${1:-"${REMOTE_HOST}"}"

  ssh::remove_host_from_known_hosts --port "${ssh_port}" "${host_name}" || softfail || return $?
  ssh::wait_for_host_to_become_available --port "${ssh_port}" "${host_name}" || softfail || return $?
  ssh::add_host_to_known_hosts --port "${ssh_port}" "${host_name}" || softfail || return $?
}

ssh::wait_for_host_to_become_available() {
  local ssh_port="${REMOTE_PORT:-"22"}"

  while [ "$#" -gt 0 ]; do
    case "$1" in
      -p|--port)
        ssh_port="$2"
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

  local host_name="${1:-"${REMOTE_HOST}"}"

  while true; do
    # note that here I omit "|| fail" for a reason, ssh-keyscan will fail if host is not yet there
    local key; key="$(ssh-keyscan -p "${ssh_port}" "${host_name}" 2>/dev/null)"
    if [ -n "${key}" ]; then
      return 0
    else
      if [ -t 2 ]; then
        echo "Waiting for SSH to become available on host '${host_name}'..." >&2
      fi
      sleep 1 || softfail || return $?
    fi
  done
}

ssh::add_host_to_known_hosts() {
  local ssh_port="${REMOTE_PORT:-"22"}"

  while [ "$#" -gt 0 ]; do
    case "$1" in
      -p|--port)
        ssh_port="$2"
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

  local host_name="${1:-"${REMOTE_HOST}"}"

  local known_hosts="${HOME}/.ssh/known_hosts"

  if ! command -v ssh-keygen >/dev/null; then
    softfail "ssh-keygen not found" || return $?
  fi

  if [ ! -f "${known_hosts}" ]; then
    dir::should_exists --mode 0700 "${HOME}/.ssh" || softfail "Unable to create ssh user config directory" || return $?
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
  local ssh_port="${REMOTE_PORT:-"22"}"

  while [ "$#" -gt 0 ]; do
    case "$1" in
      -p|--port)
        ssh_port="$2"
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

  local host_name="${1:-"${REMOTE_HOST}"}"

  if [ "${ssh_port}" = "22" ]; then
    local keygen_host_string="${host_name}"
  else
    local keygen_host_string="[${host_name}]:${ssh_port}"
  fi

  ssh-keygen -R "${keygen_host_string}" || softfail || return $?
}
