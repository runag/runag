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

direnv::write_file() {
  local name="$1"

  local dir_name=".direnv.d"
  dir::should_exists --mode 0700 "${dir_name}" || softfail || return $?

  # TODO: --absorb?
  file::write --mode 0600 "${dir_name}/${name}.sh" || softfail || return $?
}

direnv::write_block() {
  local file_mode="0600"
  local file_name=".envrc"

  while [ "$#" -gt 0 ]; do
    case $1 in
    -m|--mode)
      file_mode="$2"
      shift; shift
      ;;
    -e|--env-file)
      file_name="$2"
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

  local block_name="$1"

  if [ -n "${file_mode}" ]; then
    local umask_value
    printf -v umask_value "%o" "$(( 0777 ^ "0${file_mode}" ))" || softfail || return $?
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
  if [ -f "${file}" ]; then
    . "${file}" || echo "Unable to load ${file} ($?)" >&2
  fi
done
SHELL
}

direnv::save_directory_loader_to_block() {
  local block_name="${1:"directory-loader"}"
  direnv::directory_loader | direnv::write_block "${block_name}"
  test "${PIPESTATUS[*]}" = "0 0" || softfail || return $?
}
