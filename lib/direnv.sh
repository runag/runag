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

direnv::write-block() {
  local blockName="$1"
  local fileName="${2:-".envrc"}"
  local mode="${3:-"0640"}"

  if [ -n "${mode}" ]; then
    local umaskValue
    printf -v umaskValue "%o" "$(( 0777 ^ "0${mode}" ))" || softfail || return $?
    ( umask "${umaskValue}" && touch "${fileName}" ) || softfail || return $?
  fi

  sed -i "/^# BEGIN-SOPKA-BLOCK =${blockName}=$/,/^# END-SOPKA-BLOCK =${blockName}=$/d" "${fileName}" || softfail || return $?

  { echo "# BEGIN-SOPKA-BLOCK =${blockName}=" && cat && echo "# END-SOPKA-BLOCK =${blockName}="; } >> "${fileName}" || softfail || return $?

  direnv allow "${fileName}" || softfail || return $?
}

direnv::write-env() {
  # TODO: if 1st argument starts with 0 threat it as file mode
  local blockName="$1"
  direnv::write-env-file ".envrc" "${blockName}" "${@:2}" || softfail || return $?
}

direnv::write-env-file() {
  # TODO: if 2nd argument starts with 0 threat it as file mode
  local fileName="$1"
  local blockName="$2"

  local item; for item in "${@:3}"; do
    printf "export ${item}=%q\n" "${!item}"
  done | direnv::write-block "${blockName}" "${fileName}"

  if [[ "${PIPESTATUS[*]}" =~ [^0[:space:]] ]]; then
    softfail || return $?
  fi
}
