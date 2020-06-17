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

deploy-lib::github::get-release-by-label() {
  local repoPath="$1"
  local label="$2"
  local release="${3:-latest}"

  deploy-lib::github::get-release "${repoPath}" ".label == \"${label}\"" "${release}" || fail
}

deploy-lib::github::get-release-by-name() {
  local repoPath="$1"
  local label="$2"
  local release="${3:-latest}"

  deploy-lib::github::get-release "${repoPath}" ".name | test(\"${label}\")" "${release}" || fail
}

deploy-lib::github::get-release() {
  local repoPath="$1"
  local query="$2"
  local release="${3:-latest}"

  local apiUrl="https://api.github.com/repos/${repoPath}/releases/${release}"
  local jqFilter=".assets[] | select(${query}).browser_download_url"
  local fileUrl; fileUrl="$(curl --fail --silent --show-error "${apiUrl}" | jq --raw-output --exit-status "${jqFilter}"; test "${PIPESTATUS[*]}" = "0 0")" || fail

  if [ -z "${fileUrl}" ]; then
    fail "Can't find release URL for ${repoPath} that matched ${query} and release ${release}"
  fi

  local tempFile; tempFile="$(mktemp --tmpdir="${HOME}")" || fail "Unable to create temp file"

  curl \
    --location \
    --fail \
    --silent \
    --show-error \
    --output "$tempFile" \
    "$fileUrl" >/dev/null || fail "Unable to download ${fileUrl}"

  echo "${tempFile}"
}
