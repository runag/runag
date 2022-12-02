#!/usr/bin/env bash

#  Copyright 2012-2022 Stanislav Senotrusov <stan@senotrusov.com>
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


# TODO: remove ::exists/::save
# I deprecated ::exists/::save api and don't have time to update bitwarden code right now as I use pass right now

bitwarden::install_cli::snap() {(
  unset BW_SESSION BW_CLIENTID BW_CLIENTSECRET BW_PASSWORD

  if ! snap list bw >/dev/null 2>&1; then
    sudo snap install bw || softfail || return $?
  fi
)}

bitwarden::beyond_session() {(
  unset BW_SESSION BW_CLIENTID BW_CLIENTSECRET BW_PASSWORD
  "$@"
)}

bitwarden::logout_if_user_email_differs() {
  local bitwarden_email="$1"

  local bw_status; bw_status="$(bw status | jq '.status' --raw-output --exit-status; test "${PIPESTATUS[*]}" = "0 0")" || softfail || return $?

  if [ "${bw_status}" = "unlocked" ] || [ "${bw_status}" = "locked" ]; then
    local bw_current_user_email; bw_current_user_email="$(bw status | jq '.userEmail' --raw-output --exit-status; test "${PIPESTATUS[*]}" = "0 0")" || softfail || return $?
    if [ "${bw_current_user_email}" != "${bitwarden_email}" ]; then
      bw logout || softfail || return $?
    fi
  fi
}

bitwarden::is_logged_in() {
  # this function is intent to use fail (and not softfail) in case of errors

  local bw_status; bw_status="$(bw status | jq '.status' --raw-output --exit-status; test "${PIPESTATUS[*]}" = "0 0")" || fail # no softfail here!

  if [ "${bw_status}" = "unauthenticated" ]; then
    return 1
  elif [ "${bw_status}" = "unlocked" ] || [ "${bw_status}" = "locked" ]; then
    return 0
  else
    fail "Unknown bitwarden status"
  fi
}

bitwarden::login() {
  local bw_status; bw_status="$(bw status | jq '.status' --raw-output --exit-status; test "${PIPESTATUS[*]}" = "0 0")" || softfail || return $?

  if [ "${bw_status}" = "unauthenticated" ]; then
    local raw_result; raw_result="$(bw login --raw "$@")" || softfail || return $?

    if [ -n "${raw_result}" ]; then
      export BW_SESSION="${raw_result}"
    fi
    
  elif [ "${bw_status}" = "unlocked" ] || [ "${bw_status}" = "locked" ]; then
    return 0
  else
    softfail "Unknown bitwarden status" || return $?
  fi
}

bitwarden::unlock_and_sync() {
  local bw_status; bw_status="$(bw status | jq '.status' --raw-output --exit-status; test "${PIPESTATUS[*]}" = "0 0")" || softfail || return $?

  if [ "${bw_status}" = "unauthenticated" ]; then
    softfail "Please log in to bitwarden"
    return $?

  elif [ "${bw_status}" = "unlocked" ]; then
    return 0

  elif [ "${bw_status}" = "locked" ]; then
    echo "Please unlock your bitwarden vault"

    local raw_result; raw_result="$(bw unlock --raw "$@")" || softfail || return $?

    if [ -n "${raw_result}" ]; then
      export BW_SESSION="${raw_result}"
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

bitwarden::write_notes_to_file_if_not_exists() {
  local bitwarden_object_id="$1"
  local output_file="$2"
  local mode="${3:-"600"}"

  if [ ! -f "${output_file}" ] || [ "${RUNAG_UPDATE_SECRETS:-}" = "true" ]; then
    bitwarden::write_notes_to_file "${bitwarden_object_id}" "${output_file}" "${mode}" || softfail || return $?
  fi
}

bitwarden::write_notes_to_file() {
  local bitwarden_object_id="$1"
  local output_file="$2"
  local mode="${3:-"0600"}"

  bitwarden::unlock_and_sync || softfail "Unable to unlock and sync bitwarden" || return $?
  local item_data; item_data="$(bw --nointeraction get item "${bitwarden_object_id}")" || softfail "Unable to get item from bitwarden" || return $?

  (
    unset BW_SESSION BW_CLIENTID BW_CLIENTSECRET BW_PASSWORD

    local notes_data; notes_data="$(jq '.notes' --raw-output --exit-status <<< "${item_data}")" || softfail "Unable to extract notes from bitwarden data" || return $?

    <<<"${notes_data}" file::write --mode "${mode}" "${output_file}" || softfail "Unable to write to file: ${output_file}" || return $?
    
  ) || softfail || return $?
}

bitwarden::write_password_to_file_if_not_exists() {
  local bitwarden_object_id="$1"
  local output_file="$2"
  local mode="${3:-"600"}"

  if [ ! -f "${output_file}" ] || [ "${RUNAG_UPDATE_SECRETS:-}" = "true" ]; then
    bitwarden::write_password_to_file "${bitwarden_object_id}" "${output_file}" "${mode}" || softfail || return $?
  fi
}

bitwarden::write_password_to_file() {
  local bitwarden_object_id="$1"
  local output_file="$2"
  local mode="${3:-"0600"}"

  bitwarden::unlock_and_sync "Unable to unlock and sync bitwarden" || softfail || return $?
  local password_data; password_data="$(bw --nointeraction get password "${bitwarden_object_id}")" || softfail "Unable to get password from bitwarden" || return $?

  (
    unset BW_SESSION BW_CLIENTID BW_CLIENTSECRET BW_PASSWORD

    <<<"${password_data}" file::write --mode "${mode}" "${output_file}" || softfail "Unable to write to file: ${output_file}" || return $?

  ) || softfail || return $?
}

bitwarden::use() {
  local item
  local get_list=()

  for item in "$@"; do
    if [[ " item username password uri totp notes exposed attachment folder collection org-collection organization template fingerprint send " == *" ${item} "* ]]; then
      get_list+=("${item}")
      shift
    else
      break
    fi
  done

  local bitwarden_object_id="$1"
  local function_prefix="$2"

  if ! declare -f "${function_prefix}::exists" >/dev/null && ! command -v "${function_prefix}::exists" >/dev/null; then
    softfail "${function_prefix}::exists should be available as function or command"
    return $?
  fi

  if ! declare -f "${function_prefix}::save" >/dev/null && ! command -v "${function_prefix}::save" >/dev/null; then
    softfail "${function_prefix}::save should be available as function or command"
    return $?
  fi

  if [ "${RUNAG_UPDATE_SECRETS:-}" = "true" ] || ! ( unset BW_SESSION BW_CLIENTID BW_CLIENTSECRET BW_PASSWORD && "${function_prefix}::exists" "${@:3}" ); then
    bitwarden::unlock_and_sync || softfail || return $?
    
    local secrets_list=()
    for item in "${get_list[@]}"; do
      secrets_list+=("$(bw get "${item}" "${bitwarden_object_id}")") || softfail || return $?
    done

    ( unset BW_SESSION BW_CLIENTID BW_CLIENTSECRET BW_PASSWORD && "${function_prefix}::save" "${secrets_list[@]}" "${@:3}" ) || softfail || return $?
  fi
}

bitwarden::remote_file::exists() {(
  unset BW_SESSION BW_CLIENTID BW_CLIENTSECRET BW_PASSWORD

  local file_path="$1"

  ssh::call test -f "${file_path}"
)}

bitwarden::remote_file::save() {(
  unset BW_SESSION BW_CLIENTID BW_CLIENTSECRET BW_PASSWORD

  local secret_key="$1"
  local file_path="$2"
  local mode="${3:-"0600"}"

  <<<"${secret_key}" ssh::call file::write --mode "${mode}" "${file_path}" || softfail "Unable to write remote file" || return $?
)}

# sopka bitwarden::use username password uri "test record" bitwarden::test hello there

# bitwarden::test::exists() {
#   local item index=1
#   echo bitwarden::test::exists was called with:
#   for item in "$@"; do
#     echo "  ${index}: ${item}"
#     index=$((index+1))
#   done
#   false
# }
# 
# bitwarden::test::save() {
#   local item index=1
#   echo bitwarden::test::save was called with:
#   for item in "$@"; do
#     echo "  ${index}: ${item}"
#     index=$((index+1))
#   done
# }
