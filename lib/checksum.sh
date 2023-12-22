#!/usr/bin/env bash

#  Copyright 2012-2022 Rùnag project contributors
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

checksum::create_or_update() {
  local directory="$1"
  local current_checksum_file="$2"

  local checksum_algo="sha3-256"

  local new_checksum_file; new_checksum_file="$(mktemp)" || softfail || return $?

  (
    cd "${directory}" || softfail || return $?

    find . -type f ! -path "./${current_checksum_file}" "${@:3}" -exec openssl dgst "-${checksum_algo}" {} \; | LC_ALL=C sort >"${new_checksum_file}"
    test "${PIPESTATUS[*]}" = "0 0" || softfail || return $?

    if [ ! -f "${current_checksum_file}" ]; then
      if [ "${RUNAG_CREATE_CHECKSUMS_WITHOUT_CONFIRMATION:-}" != true ]; then
        cat "${new_checksum_file}" || softfail || return $?
        echo ""
      fi

      if [ "${RUNAG_CREATE_CHECKSUMS_WITHOUT_CONFIRMATION:-}" = true ] || ui::confirm "Do you want to create the checksum file: ${directory}/${current_checksum_file} (yes/no)?"; then
        cp "${new_checksum_file}" "${current_checksum_file}" || softfail || return $?

        if [ -d .git ]; then
          git add "${current_checksum_file}" || softfail || return $?
          git commit -m "Creates checksum file" "${current_checksum_file}" || softfail || return $?
        fi
      fi

      exit 0
    fi

    if diff --strip-trailing-cr "${current_checksum_file}" "${new_checksum_file}" >/dev/null 2>&1; then
      echo "Checksums are good: ${directory}/${current_checksum_file}"
      exit 0
    fi

    if command -v git >/dev/null; then
      git diff --ignore-cr-at-eol --color --unified=6 --no-index "${current_checksum_file}" "${new_checksum_file}" | tee
    else
      diff --strip-trailing-cr --context=6 --color "${current_checksum_file}" "${new_checksum_file}"
    fi

    echo ""

    if ui::confirm "Do you want to update the checksum file: ${directory}/${current_checksum_file} (yes/no)?"; then
      cp "${new_checksum_file}" "${current_checksum_file}" || softfail || return $?

      if [ -d .git ]; then
        git add "${current_checksum_file}" || softfail || return $?
        git commit -m "Updates checksum file" "${current_checksum_file}" || softfail || return $?
      fi
    fi
  )

  local result=$?

  rm "${new_checksum_file}" || softfail || return $?

  sync || softfail || return $?

  if [ "${result}" != 0 ]; then
    softfail "checksum::create_or_update failed (${result})" || return $?
  fi
}

checksum::verify() {(
  local directory="$1"
  local current_checksum_file="$2"

  local checksum_algo="sha3-256"

  local new_checksum_file; new_checksum_file="$(mktemp)" || softfail || return $?

  (
    cd "${directory}" || softfail || return $?

    if [ ! -f "${current_checksum_file}" ]; then
      softfail "Unable to find the checksum file: ${directory}/${current_checksum_file}" || return $?
    fi

    find . -type f ! -path "./${current_checksum_file}" "${@:3}" -exec openssl dgst "-${checksum_algo}" {} \; | LC_ALL=C sort >"${new_checksum_file}"
    test "${PIPESTATUS[*]}" = "0 0" || softfail || return $?

    if diff --strip-trailing-cr "${current_checksum_file}" "${new_checksum_file}" >/dev/null 2>&1; then
      echo "Checksums are good: ${directory}/${current_checksum_file}"
      exit 0
    fi

    if command -v git >/dev/null; then
      git diff --ignore-cr-at-eol --color --unified=6 --no-index "${current_checksum_file}" "${new_checksum_file}" | tee
    else
      diff --strip-trailing-cr --context=6 --color "${current_checksum_file}" "${new_checksum_file}"
    fi

    softfail "Checksums are different (!): ${directory}/${current_checksum_file}" || return $?
  )

  local result=$?

  rm "${new_checksum_file}" || softfail || return $?

  if [ "${result}" != 0 ]; then
    softfail "checksum::verify failed (${result})" || return $?
  fi
)}
