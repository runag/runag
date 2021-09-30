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
  local hostName="${1:-"${SOPKA_REMOTE_HOST}"}"
  local sshPort="${2:-"${SOPKA_REMOTE_PORT:-"22"}"}"
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
    ssh-keyscan -p "${sshPort}" -T 60 "${hostName}" >> "${knownHosts}" || fail
  fi
}

ssh::remove-host-from-known-hosts() {
  local hostName="$1"
  ssh-keygen -R "${hostName}" || fail
}

ssh::call() {
  local shellOptions="set -o nounset; "
  if [ "${SOPKA_VERBOSE:-}" = true ]; then
    shellOptions+="set -o xtrace; "
  fi

  local i envString=""
  if [ -n "${SOPKA_SEND_ENV:+x}" ]; then
    for i in "${SOPKA_SEND_ENV[@]}"; do
      envString+="export $(printf "%q" "${i}")=$(printf "%q" "${!i}"); "
    done
  fi

  local i commandString=""
  for i in "$@"; do
    commandString+="$(printf "%q" "${i}") "
  done

  ssh::make-user-config-directory-if-not-exists || fail

  ssh \
    -o ControlMaster=auto \
    -o ControlPath="${HOME}/.ssh/control-socket-%C" \
    -o ControlPersist=yes \
    -o ServerAliveInterval=25 \
    ${SOPKA_REMOTE_PORT:+-p "${SOPKA_REMOTE_PORT}"} \
    ${SOPKA_REMOTE_USER:+-l "${SOPKA_REMOTE_USER}"} \
    "${SOPKA_REMOTE_HOST}" \
    bash -c "$(printf "%q" "trap \"\" PIPE; $(declare -f); ${shellOptions}${envString}${commandString}")"
}

sshd::disable-password-authentication() {
  echo "PasswordAuthentication no" | file::sudo-write /etc/ssh/sshd_config.d/disable-password-authentication.conf || fail
}
