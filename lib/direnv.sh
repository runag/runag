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

direnv::save_variable_block() (
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

  # what is the difference between `loadedRC` and `foundRC` in `direnv status --json` output? Did I pick the right one for use below?

  local envrc_dir; envrc_dir="$(dirname "${envrc_path}")" || softfail || return $?
  local envrc_basename; envrc_basename="$(basename "${envrc_path}")" || softfail || return $?

  cd "${envrc_dir}" || softfail "Unable to change directory: ${envrc_dir}" || return $?

  local found_any; found_any="$(direnv status --json | jq --raw-output --exit-status 'if (.state | has("loadedRC")) and (.state | has("foundRC")) then if .state.loadedRC == null and .state.foundRC == null then "empty-ok" else "non-empty" end else false end'; test "${PIPESTATUS[*]}" = "0 0")" || softfail "Unable to obtain empty list from direnv status" || return $?

  if [ "${found_any}" != "empty-ok" ]; then
    local allowed_path; allowed_path="$(direnv status --json | jq --raw-output --exit-status 'if .state.loadedRC.allowed == 0 then .state.loadedRC.path else "" end'; test "${PIPESTATUS[*]}" = "0 0")" || softfail "Unable to obtain loadedRC.path from direnv status" || return $?

    if [ "${allowed_path}" != "${PWD}/${envrc_basename}" ]; then
      softfail "Found envrc file that is not currently allowed, or allowed file is different than provided: ${PWD}/${envrc_basename}"
      return $?
    fi
  fi

  shell::dump_variables --export "$@" | file::write_block --mode 0600 "${envrc_basename}" "${block_name}"

  test "${PIPESTATUS[*]}" = "0 0" || softfail || return $?
  
  direnv allow || softfail || return $?
)
