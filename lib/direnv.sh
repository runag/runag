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

direnv::save_variable_block() {
  local block_name="SHELL VARIABLES"
  local envrc_path=".envrc"

  while [ "$#" -gt 0 ]; do
    case "$1" in
      -b|--block-name)
        block_name="$2"
        shift; shift
        ;;
      -e|--envrc-path)
        envrc_path="$2"
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

  if [ -e "${envrc_path}" ]; then
    local envrc_dir; envrc_dir="$(dirname "${envrc_path}")" || softfail || return $?
    ( cd "${envrc_dir}" && direnv status | grep -qFx "Found RC allowed true" ) || softfail "Direnv rc file should be allowed first" || return $?
  fi

  shell::export_variables_as_code "$@" | file::write_block --mode 0600 "${envrc_path}" "${block_name}"

  test "${PIPESTATUS[*]}" = "0 0" || softfail || return $?
  
  direnv allow "${envrc_path}" || softfail || return $?
}
