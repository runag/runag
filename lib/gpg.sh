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

gpg::import_key() {
  local skip_if_exists trust_level should_confirm
  while [[ "$#" -gt 0 ]]; do
    case $1 in
      -c|--confirm)
        should_confirm=true
        shift
        ;;
      -s|--skip-if-exists)
        skip_if_exists=true
        shift
        ;;
      -m|--trust-marginally)
        trust_level=4
        shift
        ;;
      -f|--trust-fully)
        trust_level=5
        shift
        ;;
      -u|--trust-ultimately)
        trust_level=6
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

  local gpg_key_id="$1"
  local source_path="$2"

  local trust_levels=(- - - - marginally fully ultimately)

  if [ "${skip_if_exists:-}" = true ] && gpg --list-keys "${gpg_key_id}" >/dev/null 2>&1; then
    return
  fi

  if [ "${should_confirm:-}" = true ]; then
    local key_with_spaces; key_with_spaces="$(<<<"${gpg_key_id}" sed -E 's/(.{4})/\1 /g' | sed 's/ $//'; test "${PIPESTATUS[*]}" = "0 0")" || softfail || return $?
    local key_base64; key_base64="$(<<<"${gpg_key_id}" xxd -r -p | base64 | sed -E 's/(.{4})/\1 /g' | sed 's/ $//'; test "${PIPESTATUS[*]}" = "0 0 0 0")" || softfail || return $?

    echo "You are about to import GPG key with id: ${gpg_key_id}."

    if [ -n "${trust_level:-}" ]; then
      echo "Trust level for that key will be set to \"Trust ${trust_levels[${trust_level}]}\""
    fi

    echo "Space-separated key id: ${key_with_spaces}"
    echo "Base64-encoded key id: ${key_base64}"

    echo ""
    echo "Data to be imported:"
    echo ""
    gpg --import --import-options show-only "${source_path}" || softfail || return $?

    echo "Please confirm that it is your intention to do so by entering \"yes\""
    echo "Please prepare the key password if needed"
    echo "Please enter \"no\" if you want to continue without this key being imported."

    local action; IFS="" read -r action || softfail || return $?

    if [ "${action}" == no ]; then
      echo "Key is ignored"
      return
    fi

    if [ "${action}" != yes ]; then
      softfail || return $?
    fi
  fi

  gpg --import "${source_path}" || softfail || return $?

  if [ -n "${trust_level:-}" ]; then
    echo "${gpg_key_id}:${trust_level}:" | gpg --import-ownertrust || softfail || return $?
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
  # I want rùnag code to be bash-3.2 compatible so I can't use coproc
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

gpg::get_key_uid() {
  local source_path="$1"
  gpg --import --import-options show-only "${source_path}" | grep '^uid ' | head -n 1 | sed -E 's/^uid[[:space:]]+(.*)/\1/'
  test "${PIPESTATUS[*]}" = "0 0 0 0" || softfail || return $?
}
