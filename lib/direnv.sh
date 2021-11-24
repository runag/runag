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

direnv::write-file() {
  local name="$1"

  local dirName=".direnv.d"
  dir::make-if-not-exists "${dirName}" 700 || fail

  cat | file::write "${dirName}/${name}.sh" 600 || fail

  test "${PIPESTATUS[*]}" = "0 0" || softfail || return $?
}

direnv::write-block() {
  local blockName="$1"
  local fileName="${2:-".envrc"}"
  local mode="${3:-"0600"}"

  if [ -n "${mode}" ]; then
    local umaskValue
    printf -v umaskValue "%o" "$(( 0777 ^ "0${mode}" ))" || softfail || return $?
    ( umask "${umaskValue}" && touch "${fileName}" ) || softfail || return $?
  fi

  sed -i "/^# BEGIN-SOPKA-BLOCK =${blockName}=$/,/^# END-SOPKA-BLOCK =${blockName}=$/d" "${fileName}" || softfail || return $?

  { echo "# BEGIN-SOPKA-BLOCK =${blockName}=" && cat && echo "# END-SOPKA-BLOCK =${blockName}="; } >> "${fileName}" || softfail || return $?

  direnv allow "${fileName}" || softfail || return $?
}

direnv::save-variables() {
  local item; for item in "$@"; do
    printf "export ${item}=%q\n" "${!item}" || softfail || return $?
  done
}

direnv::save-variables-to-block() {
  local blockName="$1"
  direnv::save-variables "${@:2}" | direnv::write-block "${blockName}"
  test "${PIPESTATUS[*]}" = "0 0" || softfail || return $?
}

direnv::save-variables-to-file() {
  local fileName="$1"
  direnv::save-variables "${@:2}" | direnv::write-file "${fileName}"
  test "${PIPESTATUS[*]}" = "0 0" || softfail || return $?
}

direnv::directory-loader() {
  cat <<'SHELL'
for file in .direnv.d/*.sh; do
  . "${file}" || echo "Unable to load ${file} ($?)" >&2
done
SHELL
}

direnv::save-directory-loader-to-block() {
  local blockName="${1:"directory-loader"}"
  direnv::directory-loader | direnv::write-block "${blockName}"
  test "${PIPESTATUS[*]}" = "0 0" || softfail || return $?
}
