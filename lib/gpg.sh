#!/usr/bin/env bash

#  Copyright 2012-2022 Runag project contributors
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

gpg::import_key_with_ultimate_ownertrust() {
  local gpg_key_id="$1"
  local source_path="$2"

  if ! gpg --list-keys "${gpg_key_id}" >/dev/null 2>&1; then
    file::wait_until_available "${source_path}" || softfail || return $?

    local key_with_spaces; key_with_spaces="$(<<<"${gpg_key_id}" sed -E 's/(.{4})/\1 /g' | sed 's/ $//'; test "${PIPESTATUS[*]}" = "0 0")" || fail
    local key_base64; key_base64="$(<<<"${gpg_key_id}" xxd -r -p | base64 | sed -E 's/(.{4})/\1 /g' | sed 's/ $//'; test "${PIPESTATUS[*]}" = "0 0 0 0")" || fail

    echo "You are about to import key: ${key_with_spaces} (${key_base64})"
    echo "Please confirm that this is the key you expected to use by entering \"YES\""
    local action; IFS="" read -r action || fail

    if [ "${action}" != yes ] && [ "${action}" != YES ]; then
      fail
    fi

    gpg --import "${source_path}" || softfail || return $?
    echo "${gpg_key_id}:6:" | gpg --import-ownertrust || softfail || return $?
  fi
}

gpg::decrypt_and_install_file() {
  local source_path="$1"
  local dest_path="$2"
  local mode="${3:-"0600"}"

  if [ ! -f "${dest_path}" ]; then
    file::wait_until_available "${source_path}" || softfail || return $?
    gpg --decrypt "${source_path}" | file::write --mode "${mode}" "${dest_path}"
    test "${PIPESTATUS[*]}" = "0 0" || softfail || return $?
  fi
}

gpg::decrypt_and_source_script() {
  local source_path="$1"

  file::wait_until_available "${source_path}" || softfail || return $?

  local temp_dir; temp_dir="$(mktemp -d)" || softfail || return $?

  # I don't want to put data in file system here so I'll use fifo
  # I want runag code to be bash-3.2 compatible so I can't use coproc
  mkfifo -m 600 "${temp_dir}/fifo" || softfail || return $?

  gpg --decrypt "${source_path}" >"${temp_dir}/fifo" &
  local gpg_pid=$!

  . "${temp_dir}/fifo"
  local source_status=$?

  wait "${gpg_pid}"
  local gpg_status=$?

  rm "${temp_dir}/fifo" || softfail || return $?
  rm -d "${temp_dir}" || softfail || return $?

  test "${source_status}" = "0" || softfail || return $?
  test "${gpg_status}" = "0" || softfail || return $?
}
