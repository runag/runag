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

ssh::install-keys() {
  if [ ! -d "${HOME}/.ssh" ]; then
    mkdir -m 0700 "${HOME}/.ssh" || fail
  fi

  bitwarden::write-notes-to-file-if-not-exists "my current ssh private key" "${HOME}/.ssh/id_rsa" "077" || fail
  bitwarden::write-notes-to-file-if-not-exists "my current ssh public key" "${HOME}/.ssh/id_rsa.pub" "077" || fail
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
  local hostName="$1"
  local knownHosts="${HOME}/.ssh/known_hosts"

  if ! command -v ssh-keygen >/dev/null; then
    fail "ssh-keygen not found"
  fi

  if [ ! -f "${knownHosts}" ]; then
    local knownHostsDirname; knownHostsDirname="$(dirname "${knownHosts}")" || fail

    mkdir -p "${knownHostsDirname}" || fail
    chmod 700 "${knownHostsDirname}" || fail

    touch "${knownHosts}" || fail
    chmod 644 "${knownHosts}" || fail
  fi

  if ! ssh-keygen -F "${hostName}" >/dev/null; then
    ssh-keyscan -T 60 -H "${hostName}" >> "${knownHosts}" || fail
  fi
}

ssh::remove-host-from-known-hosts() {
  local hostName="$1"
  ssh-keygen -R "$hostName" || fail
}

ssh::get-user-public-key() {
  if [ -r "${HOME}/.ssh/id_rsa.pub" ]; then
    cat "${HOME}/.ssh/id_rsa.pub" || fail
  else
    fail "Unable to find user public key"
  fi
}

ssh::call() {
  local shellOptions="set -o nounset; "
  if [ -n "${VERBOSE:-}" ]; then
    shellOptions+="set -o xtrace; "
  fi

  local i envString=""
  if [ -n "${SEND_ENV:+x}" ]; then
    for i in "${SEND_ENV[@]}"; do
      envString+="export $(printf "%q" "${i}")=$(printf "%q" "${!i}"); "
    done
  fi

  local i argString=""
  for i in "${@}"; do
    argString+="$(printf "%q" "${i}") "
  done

   if [ ! -d "${HOME}/.ssh" ]; then
    mkdir -p -m 0700 "${HOME}/.ssh" || fail
  fi

  ssh \
    -o ControlMaster=auto \
    -o ControlPath="$HOME/.ssh/%C.control-socket" \
    -o ControlPersist=yes \
    -o ServerAliveInterval=50 \
    -o ForwardAgent=yes \
    ${REMOTE_PORT:+-p} ${REMOTE_PORT:+"${REMOTE_PORT}"} \
    ${REMOTE_USER:+-l} ${REMOTE_USER:+"${REMOTE_USER}"} \
    ${REMOTE_HOST:-} \
    bash -c "$(printf "%q" "trap \"\" PIPE; $(declare -f); ${shellOptions}${envString}${argString}")" \
    || return $?
}
