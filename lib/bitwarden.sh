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

bitwarden::install-cli::snap() {(
  unset BW_SESSION BW_CLIENTID BW_CLIENTSECRET BW_PASSWORD

  if ! snap list bw >/dev/null 2>&1; then
    sudo snap install bw || softfail || return $?
  fi

  if ! command -v jq >/dev/null; then
    apt::lazy-update || softfail || return $?
    apt::install jq || softfail || return $?
  fi
)}

bitwarden::beyond-session() {(
  unset BW_SESSION BW_CLIENTID BW_CLIENTSECRET BW_PASSWORD
  "$@"
)}

bitwarden::logout-if-user-email-differs() {
  local bitwardenEmail="$1"

  local bwStatus; bwStatus="$(bw status | jq '.status' --raw-output --exit-status; test "${PIPESTATUS[*]}" = "0 0")" || softfail || return $?

  if [ "${bwStatus}" = "unlocked" ] || [ "${bwStatus}" = "locked" ]; then
    local bwCurrentUserEmail; bwCurrentUserEmail="$(bw status | jq '.userEmail' --raw-output --exit-status; test "${PIPESTATUS[*]}" = "0 0")" || softfail || return $?
    if [ "${bwCurrentUserEmail}" != "${bitwardenEmail}" ]; then
      bw logout || softfail || return $?
    fi
  fi
}

bitwarden::is-logged-in() {
  # this function is intent to use fail (and not softfail) in case of errors

  local bwStatus; bwStatus="$(bw status | jq '.status' --raw-output --exit-status; test "${PIPESTATUS[*]}" = "0 0")" || fail

  if [ "${bwStatus}" = "unauthenticated" ]; then
    return 1
  elif [ "${bwStatus}" = "unlocked" ] || [ "${bwStatus}" = "locked" ]; then
    return 0
  else
    fail "Unknown bitwarden status"
  fi
}

bitwarden::login() {
  local bwStatus; bwStatus="$(bw status | jq '.status' --raw-output --exit-status; test "${PIPESTATUS[*]}" = "0 0")" || softfail || return $?

  if [ "${bwStatus}" = "unauthenticated" ]; then
    local rawResult; rawResult="$(bw login --raw "$@")" || softfail || return $?

    if [ -n "${rawResult}" ]; then
      export BW_SESSION="${rawResult}"
    fi
    
  elif [ "${bwStatus}" = "unlocked" ] || [ "${bwStatus}" = "locked" ]; then
    return 0
  else
    softfail "Unknown bitwarden status" || return $?
  fi
}

bitwarden::unlock-and-sync() {
  local bwStatus; bwStatus="$(bw status | jq '.status' --raw-output --exit-status; test "${PIPESTATUS[*]}" = "0 0")" || softfail || return $?

  if [ "${bwStatus}" = "unauthenticated" ]; then
    softfail "Please log in to bitwarden"
    return $?

  elif [ "${bwStatus}" = "unlocked" ]; then
    return 0

  elif [ "${bwStatus}" = "locked" ]; then
    echo "Please unlock your bitwarden vault"

    local rawResult; rawResult="$(bw unlock --raw "$@")" || softfail || return $?

    if [ -n "${rawResult}" ]; then
      export BW_SESSION="${rawResult}"
    else
      softfail "Unable to oabtain bitwarden session"
      return $?
    fi

    bw sync || softfail || return $?
  else
    softfail "Unknown bitwarden status"
    return $?
  fi
}

bitwarden::write-notes-to-file-if-not-exists() {
  local bitwardenObjectId="$1"
  local outputFile="$2"
  local mode="${3:-"600"}"

  if [ ! -f "${outputFile}" ] || [ "${SOPKA_UPDATE_SECRETS:-}" = "true" ]; then
    bitwarden::write-notes-to-file "${bitwardenObjectId}" "${outputFile}" "${mode}" || softfail || return $?
  fi
}

bitwarden::write-notes-to-file() {
  local bitwardenObjectId="$1"
  local outputFile="$2"
  local mode="${3:-"600"}"

  bitwarden::unlock-and-sync || softfail || return $?
  local bwdata; bwdata="$(bw --nointeraction get item "${bitwardenObjectId}")" || softfail || return $?

  (
    unset BW_SESSION BW_CLIENTID BW_CLIENTSECRET BW_PASSWORD
    echo "${bwdata}" | jq '.notes' --raw-output --exit-status | file::write "${outputFile}" "${mode}"
    test "${PIPESTATUS[*]}" = "0 0 0" || softfail || return $?
  ) || softfail || return $?
}

bitwarden::write-password-to-file-if-not-exists() {
  local bitwardenObjectId="$1"
  local outputFile="$2"
  local mode="${3:-"600"}"

  if [ ! -f "${outputFile}" ] || [ "${SOPKA_UPDATE_SECRETS:-}" = "true" ]; then
    bitwarden::write-password-to-file "${bitwardenObjectId}" "${outputFile}" "${mode}" || softfail || return $?
  fi
}

bitwarden::write-password-to-file() {
  local bitwardenObjectId="$1"
  local outputFile="$2"
  local mode="${3:-"600"}"

  bitwarden::unlock-and-sync || softfail || return $?
  local bwdata; bwdata="$(bw --nointeraction get password "${bitwardenObjectId}")" || softfail || return $?

  (
    unset BW_SESSION BW_CLIENTID BW_CLIENTSECRET BW_PASSWORD
    echo -n "${bwdata}" | file::write "${outputFile}" "${mode}"
    test "${PIPESTATUS[*]}" = "0 0" || softfail || return $?
  ) || softfail || return $?
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
    softfail "${functionPrefix}::exists should be available as function or command"
    return $?
  fi

  if ! declare -f "${functionPrefix}::save" >/dev/null && ! command -v "${functionPrefix}::save" >/dev/null; then
    softfail "${functionPrefix}::save should be available as function or command"
    return $?
  fi

  if [ "${SOPKA_UPDATE_SECRETS:-}" = "true" ] || ! ( unset BW_SESSION BW_CLIENTID BW_CLIENTSECRET BW_PASSWORD && "${functionPrefix}::exists" "${@:3}" ); then
    bitwarden::unlock-and-sync || softfail || return $?
    
    local secretsList=()
    for item in "${getList[@]}"; do
      secretsList+=("$(bw get "${item}" "${bitwardenObjectId}")") || softfail || return $?
    done

    ( unset BW_SESSION BW_CLIENTID BW_CLIENTSECRET BW_PASSWORD && "${functionPrefix}::save" "${secretsList[@]}" "${@:3}" ) || softfail || return $?
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
