#!/usr/bin/env bash

#  Copyright 2012-2019 Stanislav Senotrusov <stan@senotrusov.com>
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

sshd::ubuntu::install-and-configure() {
  # perform apt update
  apt::lazy-update || fail

  # configure
  sshd::configure || fail # I do it first because ubuntu starts sshd right after install and I want it to be secured already at this point

  # install end run
  apt::install openssh-server ssh-import-id || fail
  sudo systemctl --now enable ssh || fail
  sudo systemctl reload ssh || fail
}

sshd::configure() {
  fs::sudo-write-file "/etc/ssh/sshd_config.d/access.conf" <<SHELL || fail
PasswordAuthentication no
PermitEmptyPasswords no
SHELL
}

ssh::make-dot-ssh-dir-if-not-exist() {
  if [ ! -d "${HOME}/.ssh" ]; then
    mkdir "${HOME}/.ssh" || fail
    chmod 0700 "${HOME}/.ssh" || fail
  fi
}

ssh::keys-exist() {
  test -f "${HOME}/.ssh/id_ed25519" && test -f "${HOME}/.ssh/id_ed25519.pub"
}

ssh::upload-keys-if-not-exists() {
  # bitwarden-object: "? ssh private key", "? ssh public key"
  local privateKeyName="$1 ssh private key"
  local publicKeyName="$1 ssh public key"

  if ! ssh::call ssh::keys-exist; then
    ssh::upload-key "${privateKeyName}" "id_ed25519" || fail
    ssh::upload-key "${publicKeyName}" "id_ed25519.pub" || fail
  fi
}

ssh::upload-key() {
  # bitwarden-object: "?"
  local bwItem="$1"
  local fileName="$2"

  local tmpFile; tmpFile="$(mktemp)" || fail

  bitwarden::write-notes-to-file "${bwItem}" "${tmpFile}" || fail
  ssh::call ssh::make-dot-ssh-dir-if-not-exist || fail
  rsync::upload "${tmpFile}" ".ssh/${fileName}" || fail

  rm "${tmpFile}" || fail
}

ssh::install-keys() {
  local privateKeyName="$1 ssh private key"
  local publicKeyName="$1 ssh public key"

  ssh::make-dot-ssh-dir-if-not-exist || fail

  # bitwarden-object: "? ssh private key", "? ssh public key"
  bitwarden::write-notes-to-file-if-not-exists "${privateKeyName}" "${HOME}/.ssh/id_ed25519" "077" || fail
  bitwarden::write-notes-to-file-if-not-exists "${publicKeyName}" "${HOME}/.ssh/id_ed25519.pub" "077" || fail
}

ssh::get-user-public-key() {
  if [ -r "${HOME}/.ssh/id_ed25519.pub" ]; then
    cat "${HOME}/.ssh/id_ed25519.pub" || fail
  else
    fail "Unable to find user public key"
  fi
}

ssh::ubuntu::add-key-password-to-keyring() {
  local bwItem="$1"
  # There is an indirection here. I assume that if there is a DBUS_SESSION_BUS_ADDRESS available then
  # the login keyring is also available and already initialized properly
  # I don't know yet how to check for login keyring specifically
  if [ -n "${DBUS_SESSION_BUS_ADDRESS:-}" ]; then
    if ! secret-tool lookup unique "ssh-store:${HOME}/.ssh/id_ed25519" >/dev/null; then
      bitwarden::unlock || fail

      # bitwarden-object: "? password for ssh private key"
      bw get password "${bwItem} password for ssh private key" \
        | secret-tool store --label="Unlock password for: ${HOME}/.ssh/id_ed25519" unique "ssh-store:${HOME}/.ssh/id_ed25519"

      test "${PIPESTATUS[*]}" = "0 0" || fail "Unable to obtain and store ssh key password"
    fi
  else
    echo "Unable to store ssh key password into the gnome keyring, DBUS not found" >&2
  fi
}

ssh::macos::add-key-password-to-keychain() {
  local bwItem="$1"
  local keyFile="${HOME}/.ssh/id_ed25519"
  if ssh-add -L | grep --quiet --fixed-strings "${keyFile}"; then
    echo "${keyFile} is already in the keychain"
  else
    bitwarden::unlock || fail

    # bitwarden-object: "? password for ssh private key"
    local password; password="$(bw get password "${bwItem} password for ssh private key")" || fail

    # I could not pipe output directly to ssh-add because "bw get password" throws a pipe error in that case
    echo "${password}" | SSH_ASKPASS="${SOPKA_DIR}/lib/macos/exec-cat.sh" DISPLAY=1 ssh-add -K "${keyFile}"

    test "${PIPESTATUS[*]}" = "0 0" || fail "Unable to obtain and store ssh key password"
  fi
}

ssh::macos::add-use-keychain-to-config() {
  local sshConfigFile="${HOME}/.ssh/config"

  if [ ! -f "${sshConfigFile}" ]; then
    touch "${sshConfigFile}" || fail
  fi

  if grep --quiet "^# Use keychain" "${sshConfigFile}"; then
    echo "Use keychain config already present"
  else
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
    local key; key="$(ssh-keyscan "$ip" 2>/dev/null)" # note that here I omit "|| fail" for a reason, ssh-keyscan will fail if host is not yet there
    if [ ! -z "$key" ]; then
      return
    else
      echo "Waiting for SSH to become available on host '$ip'..."
      sleep 1 || fail
    fi
  done
}

ssh::refresh-host-in-known-hosts() {
  local hostName="$1"
  ssh::remove-host-from-known-hosts "$hostName" || fail
  ssh::wait-for-host-ssh-to-become-available "$hostName" || fail
  ssh::add-host-to-known-hosts "$hostName" || fail
}

ssh::add-host-to-known-hosts() {
  local hostName="${1:-"${REMOTE_HOST}"}"
  local sshPort="${2:-"${REMOTE_PORT:-"22"}"}"
  local knownHosts="${HOME}/.ssh/known_hosts"

  if ! command -v ssh-keygen >/dev/null; then
    fail "ssh-keygen not found"
  fi

  if [ ! -f "${knownHosts}" ]; then
    local knownHostsDirname; knownHostsDirname="$(dirname "${knownHosts}")" || fail

    if [ ! -d "${knownHostsDirname}" ]; then
      mkdir "${knownHostsDirname}" || fail
      chmod 0700 "${knownHostsDirname}" || fail
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
  ssh-keygen -R "$hostName" || fail
}

ssh::call() {
  local shellOptions="set -o nounset; "
  if [ "${VERBOSE:-}" = true ]; then
    shellOptions+="set -o xtrace; "
  fi

  local i envString=""
  if [ -n "${SEND_ENV:+x}" ]; then
    for i in "${SEND_ENV[@]}"; do
      envString+="export $(printf "%q" "${i}")=$(printf "%q" "${!i}"); "
    done
  fi

  local i argString=""
  for i in "$@"; do
    argString+="$(printf "%q" "${i}") "
  done

  ssh::make-dot-ssh-dir-if-not-exist || fail

  ssh \
    -o ControlMaster=auto \
    -o ControlPath="$HOME/.ssh/%C.control-socket" \
    -o ControlPersist=yes \
    -o ServerAliveInterval=25 \
    ${REMOTE_PORT:+-p} ${REMOTE_PORT:+"${REMOTE_PORT}"} \
    ${REMOTE_USER:+-l} ${REMOTE_USER:+"${REMOTE_USER}"} \
    ${REMOTE_HOST:-} \
    bash -c "$(printf "%q" "trap \"\" PIPE; $(declare -f); ${shellOptions}${envString}${argString}")" \
    || return $?
}
