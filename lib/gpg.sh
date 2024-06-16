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

gpg::get_key_uid() {
  local source_path="$1"
  gpg --import --import-options show-only "${source_path}" | grep '^uid ' | head -n 1 | sed -E 's/^uid[[:space:]]+(.*)/\1/'
  test "${PIPESTATUS[*]}" = "0 0 0 0" || softfail || return $?
}

gpg::import_key() {
  local skip_if_exists trust_level should_confirm
  local list_keys_command="--list-keys"
  while [ "$#" -gt 0 ]; do
    case "$1" in
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
      -e|--secret-key)
        list_keys_command="--list-secret-keys"
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

  if [ "${skip_if_exists:-}" = true ] && gpg "${list_keys_command}" "${gpg_key_id}" >/dev/null 2>&1; then
    return 0
  fi

  if [ "${should_confirm:-}" = true ]; then
    local key_with_spaces; key_with_spaces="$(<<<"${gpg_key_id}" sed -E 's/(.{4})/\1 /g' | sed 's/ $//'; test "${PIPESTATUS[*]}" = "0 0")" || softfail || return $?
    local key_base64; key_base64="$(<<<"${gpg_key_id}" xxd -r -p | base64 | sed -E 's/(.{4})/\1 /g' | sed 's/ $//'; test "${PIPESTATUS[*]}" = "0 0 0 0")" || softfail || return $?

    echo ""
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

    if ! ui::confirm; then
      log::warning "Key was not imported" || softfail || return $?
      return 0
    fi
  fi

  gpg --import "${source_path}" || softfail || return $?

  if [ -n "${trust_level:-}" ]; then
    echo "${gpg_key_id}:${trust_level}:" | gpg --import-ownertrust || softfail || return $?
  fi
}
