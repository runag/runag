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

checksums::create-or-update(){
  local directory="$1"
  local currentChecksumFile="$2"
  local checksumAlgo="${3:-"sha3-256"}"

  local newChecksumFile; newChecksumFile="$(mktemp)" || fail

  (
    cd "${directory}" || fail

    find . -type f \( -not -name "${currentChecksumFile}" \) -exec openssl dgst "-${checksumAlgo}" {} \; | sort >"${newChecksumFile}"
    test "${PIPESTATUS[*]}" = "0 0" || fail

    local action

    if [ ! -f "${currentChecksumFile}" ]; then
      cat "${newChecksumFile}" || fail
      echo ""
      echo "${directory}: Do you want to create the checksum file? (y/n)"

      IFS="" read -r action || fail

      if [ "${action}" = y ] || [ "${action}" = Y ]; then
        cp "${newChecksumFile}" "${currentChecksumFile}" || fail
      fi

      sync || fail
      exit 0
    fi

    if diff --strip-trailing-cr "${currentChecksumFile}" "${newChecksumFile}" >/dev/null 2>&1; then
      echo "${directory}: Checksums are good"
      exit 0
    fi

    if command -v git >/dev/null; then
      git diff --ignore-cr-at-eol --color --unified=6 --no-index "${currentChecksumFile}" "${newChecksumFile}" | tee
    else
      diff --strip-trailing-cr --context=6 --color "${currentChecksumFile}" "${newChecksumFile}"
    fi

    echo ""
    echo "${directory}: Do you want to update the checksum file? (y/n)"

    IFS="" read -r action || fail

    if [ "${action}" = y ] || [ "${action}" = Y ]; then
      cp "${newChecksumFile}" "${currentChecksumFile}" || fail
      sync || fail
    fi
  )

  local result=$?

  rm "${newChecksumFile}" || fail

  if [ "${result}" != 0 ]; then
    fail "checksums::create-or-update failed (${result})"
  fi
}

checksums::verify()(
  local directory="$1"
  local currentChecksumFile="$2"
  local checksumAlgo="${3:-"sha3-256"}"

  local newChecksumFile; newChecksumFile="$(mktemp)" || fail

  (
    cd "${directory}" || fail

    if [ ! -f "${currentChecksumFile}" ]; then
      fail "${directory}: Unable to find checksum file ${currentChecksumFile}"
    fi

    find . -type f \( -not -name "${currentChecksumFile}" \) -exec openssl dgst "-${checksumAlgo}" {} \; | sort >"${newChecksumFile}"
    test "${PIPESTATUS[*]}" = "0 0" || fail

    if diff --strip-trailing-cr "${currentChecksumFile}" "${newChecksumFile}" >/dev/null 2>&1; then
      echo "${directory}: Checksums are ok"
      exit 0
    fi

    if command -v git >/dev/null; then
      git diff --ignore-cr-at-eol --color --unified=6 --no-index "${currentChecksumFile}" "${newChecksumFile}" | tee
    else
      diff --strip-trailing-cr --context=6 --color "${currentChecksumFile}" "${newChecksumFile}"
    fi

    fail "${directory}: Checksums are different!"
  )

  local result=$?

  rm "${newChecksumFile}" || fail

  if [ "${result}" != 0 ]; then
    fail "checksums::verify failed (${result})"
  fi
)
