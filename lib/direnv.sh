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

direnv::write_file() {
  local name="$1"

  local dir_name=".direnv.d"
  dir::make_if_not_exists "${dir_name}" 700 || softfail || return $?

  cat | file::write "${dir_name}/${name}.sh" 600 || softfail || return $?

  test "${PIPESTATUS[*]}" = "0 0" || softfail || return $?
}

direnv::write_block() {
  local block_name="$1"
  local file_name="${2:-".envrc"}"
  local mode="${3:-"0600"}"

  if [ -n "${mode}" ]; then
    local umask_value
    printf -v umask_value "%o" "$(( 0777 ^ "0${mode}" ))" || softfail || return $?
    ( umask "${umask_value}" && touch "${file_name}" ) || softfail || return $?
  fi

  sed -i "/^# BEGIN ${block_name}$/,/^# END ${block_name}$/d" "${file_name}" || softfail || return $?

  { echo "# BEGIN ${block_name}" && cat && echo "# END ${block_name}"; } >> "${file_name}" || softfail || return $?

  direnv allow "${file_name}" || softfail || return $?
}

direnv::save_variables() {
  local item; for item in "$@"; do
    printf "export ${item}=%q\n" "${!item}" || softfail || return $?
  done
}

direnv::save_variables_to_block() {
  local block_name="$1"
  direnv::save_variables "${@:2}" | direnv::write_block "${block_name}"
  test "${PIPESTATUS[*]}" = "0 0" || softfail || return $?
}

direnv::save_variables_to_file() {
  local file_name="$1"
  direnv::save_variables "${@:2}" | direnv::write_file "${file_name}"
  test "${PIPESTATUS[*]}" = "0 0" || softfail || return $?
}

direnv::directory_loader() {
  cat <<'SHELL'
for file in .direnv.d/*.sh; do
  . "${file}" || echo "Unable to load ${file} ($?)" >&2
done
SHELL
}

direnv::save_directory_loader_to_block() {
  local block_name="${1:"directory-loader"}"
  direnv::directory_loader | direnv::write_block "${block_name}"
  test "${PIPESTATUS[*]}" = "0 0" || softfail || return $?
}
