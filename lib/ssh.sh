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

ssh::make-home-dot-ssh-dir-if-not-exist() {
  if [ ! -d "${HOME}/.ssh" ]; then
    mkdir -m 700 "${HOME}/.ssh" || fail
  fi
}

ssh::install-keys() {
  local privateKeyName="$1 ssh private key"
  local publicKeyName="$1 ssh public key"
  local fileName="${2:-"id_ed25519"}"

  ssh::make-home-dot-ssh-dir-if-not-exist || fail

  # bitwarden-object: "? ssh private key", "? ssh public key"
  bitwarden::write-notes-to-file-if-not-exists "${privateKeyName}" "${HOME}/.ssh/${fileName}" "077" || fail
  bitwarden::write-notes-to-file-if-not-exists "${publicKeyName}" "${HOME}/.ssh/${fileName}.pub" "077" || fail
}

ssh::get-user-public-key() {
  local fileName="${1:-"id_ed25519"}"
  if [ -r "${HOME}/.ssh/${fileName}.pub" ]; then
    cat "${HOME}/.ssh/${fileName}.pub" || fail
  else
    fail "Unable to find user public key"
  fi
}

ssh::add-key-password-to-gnome-keyring() {
  local bwItem="$1"
  local fileName="${2:-"id_ed25519"}"
  # There is an indirection here. I assume that if there is a DBUS_SESSION_BUS_ADDRESS available then
  # the login keyring is also available and already initialized properly
  # I don't know yet how to check for login keyring specifically
  if [ -n "${DBUS_SESSION_BUS_ADDRESS:-}" ]; then
    if [ "${SOPKA_UPDATE_SECRETS:-}" = "true" ] || ! secret-tool lookup unique "ssh-store:${HOME}/.ssh/${fileName}" >/dev/null; then
      bitwarden::unlock || fail

      # bitwarden-object: "? password for ssh private key"
      NODENV_VERSION=system bw get password "${bwItem} password for ssh private key" \
        | secret-tool store --label="Unlock password for: ${HOME}/.ssh/${fileName}" unique "ssh-store:${HOME}/.ssh/${fileName}"
      test "${PIPESTATUS[*]}" = "0 0" || fail "Unable to obtain and store ssh key password"
    fi
  else
    echo "Unable to store ssh key password into the gnome keyring, DBUS not found" >&2
  fi
}

ssh::add-key-password-to-macos-keychain() {
  local bwItem="$1"
  local fileName="${2:-"id_ed25519"}"

  local keyFile="${HOME}/.ssh/${fileName}"

  if [ "${SOPKA_UPDATE_SECRETS:-}" = "true" ] || ! ssh-add -L | grep --quiet --fixed-strings "${keyFile}"; then
    bitwarden::unlock || fail

    # bitwarden-object: "? password for ssh private key"
    local password; password="$(NODENV_VERSION=system bw get password "${bwItem} password for ssh private key")" || fail

    local tmpFile; tmpFile="$(mktemp)" || fail
    chmod 755 "${tmpFile}" || fail
    builtin printf "#!/usr/bin/env bash\nexec cat\n" >"${tmpFile}" || fail

    # I could not pipe output directly to ssh-add because "bw get password" throws a pipe error in that case
    echo "${password}" | SSH_ASKPASS="${tmpFile}" DISPLAY=1 ssh-add -K "${keyFile}"
    test "${PIPESTATUS[*]}" = "0 0" || fail "Unable to obtain and store ssh key password"

    rm "${tmpFile}" || fail
  else
    echo "${keyFile} is already in the keychain"
  fi
}

ssh::add-use-macos-keychain-to-config() {
  local sshConfigFile="${HOME}/.ssh/config"

  if [ ! -f "${sshConfigFile}" ]; then
    touch "${sshConfigFile}" || fail
  fi

  if ! grep --quiet "^# Use keychain" "${sshConfigFile}"; then
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
    local knownHostsDirname; knownHostsDirname="$(dirname "${knownHosts}")" || fail

    if [ ! -d "${knownHostsDirname}" ]; then
      mkdir -m 700 "${knownHostsDirname}" || fail
    fi

    touch "${knownHosts}" || fail
    chmod 644 "${knownHosts}" || fail
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

  local i argString=""
  for i in "$@"; do
    argString+="$(printf "%q" "${i}") "
  done

  ssh::make-home-dot-ssh-dir-if-not-exist || fail

  ssh \
    -o ControlMaster=auto \
    -o ControlPath="${HOME}/.ssh/%C.control-socket" \
    -o ControlPersist=yes \
    -o ServerAliveInterval=25 \
    ${SOPKA_REMOTE_PORT:+-p} ${SOPKA_REMOTE_PORT:+"${SOPKA_REMOTE_PORT}"} \
    ${SOPKA_REMOTE_USER:+-l} ${SOPKA_REMOTE_USER:+"${SOPKA_REMOTE_USER}"} \
    ${SOPKA_REMOTE_HOST:-} \
    bash -c "$(printf "%q" "trap \"\" PIPE; $(declare -f); ${shellOptions}${envString}${argString}")" \
    || return $?
}

ssh::disable-password-authentication() {
  echo "PasswordAuthentication no" | file::sudo-write "/etc/ssh/sshd_config.d/disable-password-authentication.conf" || fail
}
