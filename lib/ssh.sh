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

deploy-lib::ssh::install-keys() {
  if [ ! -d "${HOME}/.ssh" ]; then
    mkdir -m 0700 "${HOME}/.ssh" || fail
  fi

  deploy-lib::bitwarden::write-notes-to-file-if-not-exists "my current ssh private key" "${HOME}/.ssh/id_rsa" "077" || fail
  deploy-lib::bitwarden::write-notes-to-file-if-not-exists "my current ssh public key" "${HOME}/.ssh/id_rsa.pub" "077" || fail
}

deploy-lib::ssh::add-host-known-hosts() {
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
