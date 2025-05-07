#!/usr/bin/env bash

#  Copyright 2012-2025 Runag project contributors
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

github::install_profile_from_pass() {
  local pass_path="$1"
  
  if [[ "${OSTYPE}" =~ ^linux ]]; then
    git::use_libsecret_credential_helper || softfail || return $?

    local github_username; github_username="$(pass::use "${pass_path}/username")" || softfail || return $?

    pass::use "${pass_path}/personal-access-token" git::gnome_keyring_credentials "github.com" "${github_username}" || softfail || return $?
  fi
}

# github::query_release --get tag_name asdf-vm/asdf
github::query_release() {
  local release_id="latest"
  local query_string

  while [ "$#" -gt 0 ]; do
    case "$1" in
      -r|--release-id)
        release_id="$2"
        shift; shift
        ;;
      -g|--get)
        query_string=".$2"
        shift; shift
        ;;
      -q|--query)
        query_string="$2"
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

  if [ -z "${query_string:-}" ]; then
    softfail "Query string should be specified" || return $?
  fi

  local repo_path="$1"

  local api_url="https://api.github.com/repos/${repo_path}/releases/${release_id}"

  curl --fail --silent --show-error "${api_url}" | jq --raw-output --exit-status "${query_string}"

  test "${PIPESTATUS[*]}" = "0 0" || softfail || return $?
}

github::download_release() {
  local release_id="latest"
  local query_string

  while [ "$#" -gt 0 ]; do
    case "$1" in
      -r|--release-id)
        release_id="$2"
        shift; shift
        ;;
      -q|--query)
        query_string="$2"
        shift; shift
        ;;
      -l|--asset-label)
        query_string=".assets[] | select(.label == \"$2\").browser_download_url"
        shift; shift
        ;;
      -n|--asset-name)
        query_string=".assets[] | select(.name | test(\"$2\")).browser_download_url"
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

  if [ -z "${query_string:-}" ]; then
    softfail "Query string should be specified" || return $?
  fi

  local repo_path="$1"

  local file_url; file_url="$(github::query_release --release-id "${release_id}" --query "${query_string}" "${repo_path}")" || softfail || return $?

  if [ -z "${file_url}" ]; then
    softfail "Can't find release URL for ${repo_path} that matched ${query_string} and release ${release_id}" || return $?
  fi

  local temp_file; temp_file="$(mktemp)" || softfail "Unable to create temp file" || return $?

  curl \
    --location \
    --fail \
    --silent \
    --show-error \
    --output "${temp_file}" \
    "${file_url}" >/dev/null || softfail "Unable to download ${file_url}" || return $?

  echo "${temp_file}"
}
