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

bitwarden::snap::install-cli() (
  unset BW_SESSION

  if ! snap list bw >/dev/null 2>&1; then
    sudo snap install bw || fail
  fi

  if ! command -v jq >/dev/null; then
    apt::lazy-update || fail
    apt::install jq || fail
  fi
)

bitwarden::install-bitwarden-login-shellrc() {
  file::write "${HOME}/.shellrc.d/set-bitwarden-login.sh" <<SHELL || fail
    export SOPKA_BITWARDEN_LOGIN="${SOPKA_BITWARDEN_LOGIN}"
SHELL
}

bitwarden::unlock() {
  if [ -z "${BW_SESSION:-}" ]; then
    # the absence of error handling is intentional here
    local errorString; errorString="$(NODENV_VERSION=system bw login "${SOPKA_BITWARDEN_LOGIN}" --raw 2>&1 </dev/null)"

    if [ "${errorString}" != "You are already logged in as ${SOPKA_BITWARDEN_LOGIN}." ]; then
      # Check if we have terminal
      if [ ! -t 0 ]; then
        fail "Terminal input should be available"
      fi

      echo "Please enter your bitwarden password to login"

      BW_SESSION="$(NODENV_VERSION=system bw login "${SOPKA_BITWARDEN_LOGIN}" --raw)" || fail "Unable to login to bitwarden"
      export BW_SESSION
    fi
  fi

  if [ -z "${BW_SESSION:-}" ]; then
    # Check if we have terminal
    if [ ! -t 0 ]; then
      fail "Terminal input should be available"
    fi

    echo "Please enter your bitwarden password to unlock the vault"

    BW_SESSION="$(NODENV_VERSION=system bw unlock --raw)" || fail "Unable to unlock bitwarden database"
    export BW_SESSION

    NODENV_VERSION=system bw sync || fail "Unable to sync bitwarden"
  fi
}

bitwarden::write-notes-to-file-if-not-exists() {
  local item="$1"
  local outputFile="$2"
  local setUmask="${3:-"077"}"

  if [ ! -f "${outputFile}" ] || [ "${SOPKA_UPDATE_SECRETS:-}" = "true" ]; then
    bitwarden::write-notes-to-file "${item}" "${outputFile}" "${setUmask}" || fail
  fi
}

bitwarden::write-notes-to-file() {
  local item="$1"
  local outputFile="$2"
  local setUmask="${3:-"077"}"

  # bitwarden-object: "?"
  bitwarden::unlock || fail
  local bwdata; bwdata="$(bw --nointeraction get item "${item}")" || fail

  (
    unset BW_SESSION
    umask "${setUmask}" || fail
    builtin printf "${bwdata}" | jq '.notes' --raw-output --exit-status | file::write "${outputFile}"

    local savedPipeStatus="${PIPESTATUS[*]}"
    test "${savedPipeStatus}" = "0 0 0" || fail "bitwarden::write-notes-to-file error ${savedPipeStatus}"
  ) || fail
}

bitwarden::write-password-to-file-if-not-exists() {
  local item="$1"
  local outputFile="$2"
  local setUmask="${3:-"077"}"

  if [ ! -f "${outputFile}" ] || [ "${SOPKA_UPDATE_SECRETS:-}" = "true" ]; then
    bitwarden::write-password-to-file "${item}" "${outputFile}" "${setUmask}" || fail
  fi
}

bitwarden::write-password-to-file() {
  local item="$1"
  local outputFile="$2"
  local setUmask="${3:-"077"}"

  # bitwarden-object: "?"
  bitwarden::unlock || fail
  local bwdata; bwdata="$(bw --nointeraction get password "${item}")" || fail

  (
    unset BW_SESSION
    umask "${setUmask}" || fail
    builtin printf "${bwdata}" | file::write "${outputFile}"

    local savedPipeStatus="${PIPESTATUS[*]}"
    test "${savedPipeStatus}" = "0 0" || fail "bitwarden::write-password-to-file error ${savedPipeStatus}"
  ) || fail
}
