#!/usr/bin/env bash

#  Copyright 2012-2023 Rùnag project contributors
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

aws::write_pass_credentials_to_file() {
  local profile_name="default"

  while [[ "$#" -gt 0 ]]; do
    case $1 in
    -p|--profile)
      profile_name="$2"
      shift; shift
      ;;
    -*)
      softfail "Unknown argument: $1" || return $?
      ;;
    *)
      break
      ;;
    esac
  done

  local pass_path="$1"

  local aws_access_key_id; aws_access_key_id="$(pass::use "${pass_path}/id")" || softfail || return $?
  local aws_secret_access_key; aws_secret_access_key="$(pass::use "${pass_path}/secret")" || softfail || return $?

  file::write_block --mode 0600 "${AWS_SHARED_CREDENTIALS_FILE}" "PROFILE ${profile_name}" <<INI || softfail || return $?
[${profile_name}]
aws_access_key_id=${aws_access_key_id}
aws_secret_access_key=${aws_secret_access_key}
INI
}

aws::create_access_key_and_save_to_pass() {
  local user_name="$1"
  local pass_path="$2"

  local access_key; access_key="$(aws iam create-access-key --user-name "${user_name}")" || softfail || return $?

  <<<"${access_key}" jq --raw-output --exit-status .AccessKey.AccessKeyId | pass insert --multiline --force "${pass_path}/id"
  test "${PIPESTATUS[*]}" = "0 0" || softfail || return $?

  <<<"${access_key}" jq --raw-output --exit-status .AccessKey.SecretAccessKey | pass insert --multiline --force "${pass_path}/secret"
  test "${PIPESTATUS[*]}" = "0 0" || softfail || return $?
}
