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

bitwarden::unlock() {
  if [ -z "${BW_SESSION:-}" ]; then
    # the absence of error handling is intentional here
    local errorString; errorString="$(bw login "${BITWARDEN_LOGIN}" --raw 2>&1 </dev/null)"

    if [ "${errorString}" != "You are already logged in as ${BITWARDEN_LOGIN}." ]; then
      echo "Please enter your bitwarden password to login"

      BW_SESSION="$(bw login "${BITWARDEN_LOGIN}" --raw)" || fail "Unable to login to bitwarden"
      export BW_SESSION
    fi
  fi

  if [ -z "${BW_SESSION:-}" ]; then
    echo "Please enter your bitwarden password to unlock the vault"

    BW_SESSION="$(bw unlock --raw)" || fail "Unable to unlock bitwarden database"
    export BW_SESSION

    bw sync || fail "Unable to sync bitwarden"
  fi
}

bitwarden::write-notes-to-file-if-not-exists() {
  local item="$1"
  local outputFile="$2"
  local setUmask="${3:-"077"}"

  if [ ! -f "${outputFile}" ]; then
    bitwarden::write-notes-to-file "$1" "$2" "$3" || fail
  fi
}

bitwarden::write-notes-to-file() {
  local item="$1"
  local outputFile="$2"
  local setUmask="${3:-"077"}"
  local bwdata

  bitwarden::unlock || fail

  # bitwarden-object: "?"
  if bwdata="$(bw get item "${item}")"; then
    local dirName; dirName="$(dirname "${outputFile}")" || fail

    if [ ! -d "${dirName}" ]; then
      (umask "${setUmask}" && mkdir -p "${dirName}") || fail
    fi

    builtin echo "${bwdata}" | jq '.notes' --raw-output --exit-status | (umask "${setUmask}" && tee "${outputFile}.tmp" >/dev/null)
    local savedPipeStatus="${PIPESTATUS[*]}"

    if [ "${savedPipeStatus}" = "0 0 0" ]; then
      if [ ! -s "${outputFile}.tmp" ]; then
        rm "${outputFile}.tmp" || fail "Unable to remove temp file: ${outputFile}.tmp"
        fail "Bitwarden item ${item} expected to have a non-empty note field"
      fi
      mv "${outputFile}.tmp" "${outputFile}" || fail "Unable to move temp file to the output file: ${outputFile}.tmp to ${outputFile}"
    else
      rm "${outputFile}.tmp" || fail "Unable to remove temp file: ${outputFile}.tmp"
      fail "Unable to produce '${outputFile}' (${savedPipeStatus}), bitwarden item '${item}' may not present or have an empty note field"
    fi
  else
    # echo "${bwdata}" >&2
    fail "Unable to get bitwarden item ${item}"
  fi
}

bitwarden::write-password-to-file-if-not-exists() {
  local item="$1"
  local outputFile="$2"
  local setUmask="${3:-"077"}"
  local bwdata

  if [ ! -f "${outputFile}" ]; then
    bitwarden::unlock || fail

    # bitwarden-object: "?"
    if bwdata="$(bw get password "${item}")"; then
      local dirName; dirName="$(dirname "${outputFile}")" || fail

      if [ ! -d "${dirName}" ]; then
        (umask "${setUmask}" && mkdir -p "${dirName}") || fail
      fi

      builtin echo "${bwdata}" | (umask "${setUmask}" && tee "${outputFile}.tmp" >/dev/null)
      local savedPipeStatus="${PIPESTATUS[*]}"

      if [ "${savedPipeStatus}" = "0 0" ]; then
        if [ ! -s "${outputFile}.tmp" ]; then
          rm "${outputFile}.tmp" || fail "Unable to remove temp file: ${outputFile}.tmp"
          fail "Bitwarden item ${item} expected to have a non-empty note field"
        fi
        mv "${outputFile}.tmp" "${outputFile}" || fail "Unable to move temp file to the output file: ${outputFile}.tmp to ${outputFile}"
      else
        rm "${outputFile}.tmp" || fail "Unable to remove temp file: ${outputFile}.tmp"
        fail "Unable to produce '${outputFile}' (${savedPipeStatus}), bitwarden item '${item}' may not present or have an empty note field"
      fi
    else
      # echo "${bwdata}" >&2
      fail "Unable to get bitwarden password ${item}"
    fi
  fi
}

bitwarden::shellrcd::set-bitwarden-login() {
  fs::write-file "${HOME}/.shellrc.d/set-bitwarden-login.sh" <<SHELL || fail
    export BITWARDEN_LOGIN="${BITWARDEN_LOGIN}"
SHELL
}
