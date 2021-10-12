#!/usr/bin/env bash

#  Copyright 2012-2021 Stanislav Senotrusov <stan@senotrusov.com>
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

sshd::disable-password-authentication() {
  echo "PasswordAuthentication no" | file::sudo-write /etc/ssh/sshd_config.d/disable-password-authentication.conf || fail
}

ssh::make-user-config-directory-if-not-exists() {
  dir::make-if-not-exists "${HOME}/.ssh" 700 || fail
}

ssh::get-user-public-key() {
  local fileName="${1:-"id_ed25519"}"
  if [ -r "${HOME}/.ssh/${fileName}.pub" ]; then
    cat "${HOME}/.ssh/${fileName}.pub" || fail
  else
    fail "Unable to find user public key"
  fi
}

ssh::gnome-keyring-credentials::exists() {
  local keyFile="${1:-"id_ed25519"}"

  local keyFilePath="${HOME}/.ssh/${keyFile}"

  secret-tool lookup unique "ssh-store:${keyFilePath}" >/dev/null
}

ssh::gnome-keyring-credentials::save() {
  local password="$1"
  local keyFile="${2:-"id_ed25519"}"

  local keyFilePath="${HOME}/.ssh/${keyFile}"

  echo -n "${password}" | secret-tool store --label="Unlock password for: ${keyFilePath}" unique "ssh-store:${keyFilePath}"
  test "${PIPESTATUS[*]}" = "0 0" || fail
}

ssh::macos-keychain::exists() {
  local keyFile="${1:-"id_ed25519"}"

  local keyFilePath="${HOME}/.ssh/${keyFile}"

  ssh-add -L | grep -qF "${keyFilePath}"
}

ssh::macos-keychain::save() {
  local password="$1"
  local keyFile="${2:-"id_ed25519"}"

  local keyFilePath="${HOME}/.ssh/${keyFile}"

  local tmpFile; tmpFile="$(mktemp)" || fail
  chmod 755 "${tmpFile}" || fail
  printf "#!/bin/sh\nexec cat\n" >"${tmpFile}" || fail

  echo "${password}" | SSH_ASKPASS="${tmpFile}" DISPLAY=1 ssh-add -K "${keyFilePath}"
  test "${PIPESTATUS[*]}" = "0 0" || fail

  rm "${tmpFile}" || fail
}

ssh::macos-keychain::configure-use-on-all-hosts() {
  local sshConfigFile="${HOME}/.ssh/config"

  if [ ! -f "${sshConfigFile}" ]; then
    touch "${sshConfigFile}" || fail
  fi

  if ! grep -q "^# Use keychain" "${sshConfigFile}"; then
tee -a "${sshConfigFile}" <<SHELL || fail "Unable to append to the file: ${sshConfigFile}"

# Use keychain
Host *
  UseKeychain yes
  AddKeysToAgent yes
SHELL
  fi
}

ssh::wait-for-host-ssh-to-become-available() {
  local ip="$1"
  while true; do
    # note that here I omit "|| fail" for a reason, ssh-keyscan will fail if host is not yet there
    local key; key="$(ssh-keyscan "${ip}" 2>/dev/null)"
    if [ -n "${key}" ]; then
      return
    else
      if [ -t 1 ]; then
        echo "Waiting for SSH to become available on host '${ip}'..." >&2
      fi
      sleep 1 || fail
    fi
  done
}

ssh::refresh-host-in-known-hosts() {
  local hostName="$1"
  ssh::remove-host-from-known-hosts "${hostName}" || fail
  ssh::wait-for-host-ssh-to-become-available "${hostName}" || fail
  ssh::add-host-to-known-hosts "${hostName}" || fail
}

ssh::add-host-to-known-hosts() {
  local hostName="${1:-"${REMOTE_HOST}"}"
  local sshPort="${2:-"${REMOTE_PORT:-"22"}"}"
  local knownHosts="${HOME}/.ssh/known_hosts"

  if ! command -v ssh-keygen >/dev/null; then
    fail "ssh-keygen not found"
  fi

  if [ ! -f "${knownHosts}" ]; then
    ssh::make-user-config-directory-if-not-exists || fail
    (umask 133 && touch "${knownHosts}") || fail
  fi

  if [ "${sshPort}" = "22" ]; then
    local keygenHostString="${hostName}"
  else
    local keygenHostString="[${hostName}]:${sshPort}"
  fi

  if ! ssh-keygen -F "${keygenHostString}" >/dev/null; then
    ssh-keyscan -p "${sshPort}" -T 120 "${hostName}" >> "${knownHosts}" || fail
  fi
}

ssh::remove-host-from-known-hosts() {
  local hostName="$1"
  ssh-keygen -R "${hostName}" || fail
}

ssh::set-args() {
  if ! [[ "${OSTYPE}" =~ ^msys ]] && [ "${REMOTE_CONTROL_MASTER:-}" != "no" ]; then
    sshArgs+=("-o" "ControlMaster=${REMOTE_CONTROL_MASTER:-"auto"}")
    sshArgs+=("-S" "${REMOTE_CONTROL_PATH:-"${HOME}/.ssh/control-socket.%C"}")
    sshArgs+=("-o" "ControlPersist=${REMOTE_CONTROL_PERSIST:-"600"}")
  fi

  if [ -n "${REMOTE_IDENTITY_FILE:-}" ]; then
    sshArgs+=("-i" "${REMOTE_IDENTITY_FILE}")
  fi

  if [ -n "${REMOTE_PORT:-}" ]; then
    sshArgs+=("-p" "${REMOTE_PORT}")
  fi

  if [ "${REMOTE_SERVER_ALIVE_INTERVAL:-}" != "no" ]; then
    # the idea of 20 seconds is from https://datatracker.ietf.org/doc/html/rfc3948
    sshArgs+=("-o" "ServerAliveInterval=${REMOTE_SERVER_ALIVE_INTERVAL:-"20"}")
  fi

  if [ -n "${REMOTE_USER:-}" ]; then
    sshArgs+=("-l" "${REMOTE_USER}")
  fi

  if declare -p REMOTE_SSH_ARGS >/dev/null 2>&1; then
    sshArgs=("${sshArgs[@]}" "${REMOTE_SSH_ARGS[@]}")
  fi
}

ssh::shell-options() {
  if shopt -o -q xtrace || [ "${SOPKA_VERBOSE:-}" = true ]; then
    echo "set -o xtrace"
  fi

  if shopt -o -q nounset; then
    echo "set -o nounset"
  fi
}

ssh::remote-env::base-list() {
  echo "SOPKA_UPDATE_SECRETS SOPKA_VERBOSE_TASKS SOPKA_VERBOSE"
}

ssh::remote-env() {
  local baseList; baseList="$(ssh::remote-env::base-list)" || softfail || return

  local list; IFS=" " read -r -a list <<< "${REMOTE_ENV:-} ${baseList}" || softfail || return

  local item; for item in "${list[@]}"; do
    if [ -n "${!item:-}" ]; then
      echo "export $(printf "%q=%q" "${item}" "${!item}")"
    fi
  done
}

ssh::script() {
  ssh::shell-options || softfail || return
  ssh::remote-env || softfail || return

  declare -f || softfail || return

  printf "%q " "$@" || softfail || return
}

ssh::run() {
  if [ -z "${REMOTE_HOST:-}" ]; then
    softfail "REMOTE_HOST should be set"
    return
  fi
  
  local sshArgs=() tmpFile scriptChecksum remoteTmpFile

  ssh::make-user-config-directory-if-not-exists || softfail || return

  ssh::set-args || softfail || return

  tmpFile="$(mktemp)" || softfail || return

  ssh::script "$@" >"${tmpFile}" || softfail || return

  scriptChecksum="$(cksum <"${tmpFile}")" || softfail || return

  remoteTmpFile="$(ssh "${sshArgs[@]}" "${REMOTE_HOST}" 'tmpFile="$(mktemp)" && cat>"$tmpFile" && echo "$tmpFile"' <"$tmpFile")" || softfail || return

  if [ -z "${remoteTmpFile}" ]; then
    softfail "Unable to get remote temp file name"
    return
  fi

  # shellcheck disable=2029,2016
  ssh "${sshArgs[@]}" "${REMOTE_HOST}" "$(printf 'if [ "$(cksum <%q)" != %q ]; then exit 254; fi; bash %q; scriptStatus=$?; rm -f %q; exit $scriptStatus' \
    "${remoteTmpFile}" \
    "${scriptChecksum}" \
    "${remoteTmpFile}" \
    "${remoteTmpFile}")"
}
