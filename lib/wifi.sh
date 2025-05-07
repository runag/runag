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

wifi::is_available() {
  nmcli --terse device wifi rescan 2>/dev/null
}

wifi::is_connected() {
  nmcli --terse device wifi list | grep -E "^[*]" >/dev/null
}

wifi::connect() {
  local pass_path

  while [ "$#" -gt 0 ]; do
    case "$1" in
      -p|--pass-path)
        pass_path="$2"
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

  if [ -z "${pass_path:-}" ]; then
    softfail "--pass-path should be specified" || return $?
  fi

  local password_store_dir="${PASSWORD_STORE_DIR:-"${HOME}/.password-store"}"
  local absolute_item_path; for absolute_item_path in "${password_store_dir}/${pass_path}"/* ; do
    if [ -f "${absolute_item_path}/ssid.gpg" ] && [ -f "${absolute_item_path}/password.gpg" ]; then
      local item_path="${absolute_item_path:$((${#password_store_dir}+1))}"

      local ssid; ssid="$(pass::use "${item_path}/ssid")" || softfail || return $?
      local password; password="$(pass::use "${item_path}/password")" || softfail || return $?

      if nmcli device wifi connect "${ssid}" password "${password}"; then
        return 0
      fi
    fi
  done
}
