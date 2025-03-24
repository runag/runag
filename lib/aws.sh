#!/usr/bin/env bash

#  Copyright 2012-2024 Rùnag project contributors
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

aws::pass::write_credentials_file() {
  local credentials_file
  local pass_path
  local profile_name="default"
  local ssh_call=false

  while [ "$#" -gt 0 ]; do
    case "$1" in
      -c|--credentials-file)
        credentials_file="$2"
        shift; shift
        ;;
      -p|--pass-path)
        pass_path="$2"
        shift; shift
        ;;
      -e|--profile)
        profile_name="$2"
        shift; shift
        ;;
      -r|--ssh-call)
        ssh_call=true
        shift
        ;;
      -*)
        softfail "Unknown argument: $1" || return $?
        ;;
      *)
        break
        ;;
    esac
  done

  local command_prefix=()
  local default_credentials_dir="${HOME}/.aws"

  if [ "${ssh_call}" = true ]; then
    command_prefix+=("ssh::call")
    default_credentials_dir=".aws"
  fi

  credentials_file="${credentials_file:-"${AWS_SHARED_CREDENTIALS_FILE:-"${default_credentials_dir}/credentials"}"}"

  local credentials_dir; credentials_dir="$(dirname "${credentials_file}")" || softfail || return $?
  "${command_prefix[@]}" dir::ensure_exists --mode 0700 "${credentials_dir}" || softfail || return $?

  local aws_access_key_id; aws_access_key_id="$(pass::use "${pass_path}/id")" || softfail || return $?
  local aws_secret_access_key; aws_secret_access_key="$(pass::use "${pass_path}/secret")" || softfail || return $?

  "${command_prefix[@]}" file::write --mode 0600 --section "PROFILE ${profile_name}" "${credentials_file}" <<INI || softfail || return $?
[${profile_name}]
aws_access_key_id=${aws_access_key_id}
aws_secret_access_key=${aws_secret_access_key}
INI
}

aws::pass::create_access_key() {
  local pass_path
  local user_name

  while [ "$#" -gt 0 ]; do
    case "$1" in
      -p|--pass-path)
        pass_path="$2"
        shift; shift
        ;;
      -u|--user-name)
        user_name="$2"
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

  local access_key; access_key="$(aws iam create-access-key --user-name "${user_name}")" || softfail || return $?

  <<<"${access_key}" jq --raw-output --exit-status .AccessKey.AccessKeyId | pass insert --multiline "${pass_path}/id"
  test "${PIPESTATUS[*]}" = "0 0" || softfail || return $?

  <<<"${access_key}" jq --raw-output --exit-status .AccessKey.SecretAccessKey | pass insert --multiline "${pass_path}/secret"
  test "${PIPESTATUS[*]}" = "0 0" || softfail || return $?
}
