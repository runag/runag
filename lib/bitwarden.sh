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

# bitwarden::beyond-session() {
#   (
#     unset BW_SESSION
#     "$@"
#   ) || fail "Error performing ${1:-"(argument is empty)"}" $?
# }

bitwarden::login() {
  local bitwardenEmail="$1"

  local bwStatus; bwStatus="$(bw status | jq '.status' --raw-output --exit-status; test "${PIPESTATUS[*]}" = "0 0")" || fail

  if [ "${bwStatus}" = "unlocked" ] || [ "${bwStatus}" = "locked" ]; then
    local bwCurrentUserEmail; bwCurrentUserEmail="$(bw status | jq '.userEmail' --raw-output --exit-status; test "${PIPESTATUS[*]}" = "0 0")" || fail
    if [ "${bwCurrentUserEmail}" != "${bitwardenEmail}" ]; then
      bw logout || fail
      bwStatus="$(bw status | jq '.status' --raw-output --exit-status; test "${PIPESTATUS[*]}" = "0 0")" || fail
    fi
  fi

  if [ "${bwStatus}" = "unauthenticated" ]; then
    BW_SESSION="$(bw login "${bitwardenEmail}" --raw)" || fail
    export BW_SESSION
  elif [ "${bwStatus}" = "unlocked" ] || [ "${bwStatus}" = "locked" ]; then
    return 0
  else
    fail "Unknown bitwarden status"
  fi
}

bitwarden::unlock-and-sync() {
  local bwStatus; bwStatus="$(bw status | jq '.status' --raw-output --exit-status; test "${PIPESTATUS[*]}" = "0 0")" || fail

  if [ "${bwStatus}" = "unauthenticated" ]; then
    fail "Please log in to bitwarden"

  elif [ "${bwStatus}" = "unlocked" ]; then
    return 0

  elif [ "${bwStatus}" = "locked" ]; then
    echo "Please unlock your bitwarden vault"

    BW_SESSION="$(bw unlock --raw)" || fail
    export BW_SESSION

    bw sync || fail
  else
    fail "Unknown bitwarden status"
  fi
}

bitwarden::write-notes-to-file-if-not-exists() {
  local bitwardenObjectId="$1"
  local outputFile="$2"
  local setUmask="${3:-"077"}"

  if [ ! -f "${outputFile}" ] || [ "${SOPKA_UPDATE_SECRETS:-}" = "true" ]; then
    bitwarden::write-notes-to-file "${bitwardenObjectId}" "${outputFile}" "${setUmask}" || fail
  fi
}

bitwarden::write-notes-to-file() {
  local bitwardenObjectId="$1"
  local outputFile="$2"
  local setUmask="${3:-"077"}"

  bitwarden::unlock-and-sync || fail
  local bwdata; bwdata="$(bw --nointeraction get item "${bitwardenObjectId}")" || fail

  (
    unset BW_SESSION
    printf "${bwdata}" | jq '.notes' --raw-output --exit-status | file::write "${outputFile}" "${setUmask}"
    test "${PIPESTATUS[*]}" = "0 0 0" || fail
  ) || fail
}

bitwarden::write-password-to-file-if-not-exists() {
  local bitwardenObjectId="$1"
  local outputFile="$2"
  local setUmask="${3:-"077"}"

  if [ ! -f "${outputFile}" ] || [ "${SOPKA_UPDATE_SECRETS:-}" = "true" ]; then
    bitwarden::write-password-to-file "${bitwardenObjectId}" "${outputFile}" "${setUmask}" || fail
  fi
}

bitwarden::write-password-to-file() {
  local bitwardenObjectId="$1"
  local outputFile="$2"
  local setUmask="${3:-"077"}"

  bitwarden::unlock-and-sync || fail
  local bwdata; bwdata="$(bw --nointeraction get password "${bitwardenObjectId}")" || fail

  (
    unset BW_SESSION
    printf "${bwdata}" | file::write "${outputFile}" "${setUmask}"
    test "${PIPESTATUS[*]}" = "0 0" || fail
  ) || fail
}

bitwarden::use() {
  local item
  local getList=()

  for item in "$@"; do
    if [[ " item username password uri totp notes exposed attachment folder collection org-collection organization template fingerprint send " == *" ${item} "* ]]; then
      getList+=("${item}")
      shift
    else
      break
    fi
  done

  local bitwardenObjectId="$1"
  local functionPrefix="$2"

  if ! declare -f "${functionPrefix}::exists" >/dev/null && ! command -v "${functionPrefix}::exists" >/dev/null; then
    fail "${functionPrefix}::exists should be available as function or command"
  fi

  if ! declare -f "${functionPrefix}::save" >/dev/null && ! command -v "${functionPrefix}::save" >/dev/null; then
    fail "${functionPrefix}::save should be available as function or command"
  fi

  if [ "${SOPKA_UPDATE_SECRETS:-}" = "true" ] || ! ( unset BW_SESSION && "${functionPrefix}::exists" "${@:3}" ); then
    bitwarden::unlock-and-sync || fail
    
    local secretsList=()
    for item in "${getList[@]}"; do
      secretsList+=("$(bw get "${item}" "${bitwardenObjectId}")") || fail
    done

    ( unset BW_SESSION && "${functionPrefix}::save" "${secretsList[@]}" "${@:3}" ) || fail
  fi
}

# sopka bitwarden::use username password uri "test record" bitwarden::test hello there

# bitwarden::test::exists(){
#   local item index=1
#   echo bitwarden::test::exists was called with:
#   for item in "$@"; do
#     echo "  ${index}: ${item}"
#     index=$((index+1))
#   done
#   false
# }
# 
# bitwarden::test::save(){
#   local item index=1
#   echo bitwarden::test::save was called with:
#   for item in "$@"; do
#     echo "  ${index}: ${item}"
#     index=$((index+1))
#   done
# }
