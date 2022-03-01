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

github::get_release_by_label() {
  local repo_path="$1"
  local label="$2"
  local release="${3:-latest}"

  github::get-release "${repo_path}" ".label == \"${label}\"" "${release}" || fail
}

github::get_release_by_name() {
  local repo_path="$1"
  local label="$2"
  local release="${3:-latest}"

  github::get-release "${repo_path}" ".name | test(\"${label}\")" "${release}" || fail
}

github::get_release() {
  local repo_path="$1"
  local query="$2"
  local release="${3:-latest}"

  local api_url="https://api.github.com/repos/${repo_path}/releases/${release}"
  local jq_filter=".assets[] | select(${query}).browser_download_url"
  local file_url; file_url="$(curl --fail --silent --show-error "${api_url}" | jq --raw-output --exit-status "${jq_filter}"; test "${PIPESTATUS[*]}" = "0 0")" || fail

  if [ -z "${file_url}" ]; then
    fail "Can't find release URL for ${repo_path} that matched ${query} and release ${release}"
  fi

  local temp_file; temp_file="$(mktemp "${HOME}/sopka-github-get-release-XXXXXXXXXX")" || fail "Unable to create temp file"

  curl \
    --location \
    --fail \
    --silent \
    --show-error \
    --output "${temp_file}" \
    "${file_url}" >/dev/null || fail "Unable to download ${file_url}"

  echo "${temp_file}"
}
