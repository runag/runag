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

checksums::create_or_update() {
  local directory="$1"
  local current_checksum_file="$2"
  local checksum_algo="${3:-"sha3-256"}"

  local new_checksum_file; new_checksum_file="$(mktemp)" || fail

  (
    cd "${directory}" || fail

    find . -type f \( -not -name "${current_checksum_file}" \) -exec openssl dgst "-${checksum_algo}" {} \; | LC_ALL=C sort >"${new_checksum_file}"
    test "${PIPESTATUS[*]}" = "0 0" || fail

    local action

    if [ ! -f "${current_checksum_file}" ]; then
      cat "${new_checksum_file}" || fail
      echo ""
      echo "${directory}: Do you want to create the checksum file? (y/n)"

      IFS="" read -r action || fail

      if [ "${action}" = y ] || [ "${action}" = Y ]; then
        cp "${new_checksum_file}" "${current_checksum_file}" || fail
      fi

      sync || fail
      exit 0
    fi

    if diff --strip-trailing-cr "${current_checksum_file}" "${new_checksum_file}" >/dev/null 2>&1; then
      echo "${directory}: Checksums are good"
      exit 0
    fi

    if command -v git >/dev/null; then
      git diff --ignore-cr-at-eol --color --unified=6 --no-index "${current_checksum_file}" "${new_checksum_file}" | tee
    else
      diff --strip-trailing-cr --context=6 --color "${current_checksum_file}" "${new_checksum_file}"
    fi

    echo ""
    echo "${directory}: Do you want to update the checksum file? (y/n)"

    IFS="" read -r action || fail

    if [ "${action}" = y ] || [ "${action}" = Y ]; then
      cp "${new_checksum_file}" "${current_checksum_file}" || fail
      sync || fail
    fi
  )

  local result=$?

  rm "${new_checksum_file}" || fail

  if [ "${result}" != 0 ]; then
    fail "checksums::create_or_update failed (${result})"
  fi
}

checksums::verify() {(
  local directory="$1"
  local current_checksum_file="$2"
  local checksum_algo="${3:-"sha3-256"}"

  local new_checksum_file; new_checksum_file="$(mktemp)" || fail

  (
    cd "${directory}" || fail

    if [ ! -f "${current_checksum_file}" ]; then
      fail "${directory}: Unable to find checksum file ${current_checksum_file}"
    fi

    find . -type f \( -not -name "${current_checksum_file}" \) -exec openssl dgst "-${checksum_algo}" {} \; | LC_ALL=C sort >"${new_checksum_file}"
    test "${PIPESTATUS[*]}" = "0 0" || fail

    if diff --strip-trailing-cr "${current_checksum_file}" "${new_checksum_file}" >/dev/null 2>&1; then
      echo "${directory}: Checksums are good"
      exit 0
    fi

    if command -v git >/dev/null; then
      git diff --ignore-cr-at-eol --color --unified=6 --no-index "${current_checksum_file}" "${new_checksum_file}" | tee
    else
      diff --strip-trailing-cr --context=6 --color "${current_checksum_file}" "${new_checksum_file}"
    fi

    fail "${directory}: Checksums are different!"
  )

  local result=$?

  rm "${new_checksum_file}" || fail

  if [ "${result}" != 0 ]; then
    fail "checksums::verify failed (${result})"
  fi
)}
