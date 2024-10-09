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
  local skip_allow_check=false

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
      -s|--skip-allow-check)
        skip_allow_check=true
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

  local envrc_dir; envrc_dir="$(dirname "${envrc_path}")" || softfail || return $?
  local envrc_basename; envrc_basename="$(basename "${envrc_path}")" || softfail || return $?

  cd "${envrc_dir}" || softfail "Unable to change directory: ${envrc_dir}" || return $?

  if [ "${skip_allow_check}" != true ]; then
    local json_support_test; json_support_test="$(direnv status --json | head -c 1; test "${PIPESTATUS[*]}" = "0 0")" || softfail "Unable to obtain direnv status" || return $?

    if [ "${json_support_test}" = "{" ]; then
      local found_any; found_any="$(direnv status --json | jq --raw-output --exit-status 'if (.state | has("foundRC")) and (.state | has("foundRC")) then if .state.foundRC == null and .state.foundRC == null then "empty-ok" else "non-empty" end else false end'; test "${PIPESTATUS[*]}" = "0 0")" || softfail "Unable to obtain possible empty list from direnv status" || return $?

      if [ "${found_any}" != "empty-ok" ]; then
        local allowed_path

        if ! allowed_path="$(direnv status --json | jq --raw-output --exit-status 'if .state.foundRC.allowed == 0 then .state.foundRC.path else false end'; test "${PIPESTATUS[*]}" = "0 0")"; then
          direnv status --json >&2
          softfail "Found envrc file that is not currently allowed or unable to obtain foundRC.path from direnv status"
          return $?
        fi

        if [ "${allowed_path}" != "${PWD}/${envrc_basename}" ]; then
          direnv status --json >&2
          softfail "Allowed envrc file path is different than provided: ${PWD}/${envrc_basename}"
          return $?
        fi
      fi
    else
      if ! { direnv status | grep -qFx "No .envrc or .env found" || { direnv status | grep -qFx "Found RC path ${PWD}/${envrc_basename}" && { direnv status | grep -qFx "Found RC allowed 0" || direnv status | grep -qFx "Found RC allowed true"; }; }; }; then
        direnv status >&2
        softfail "Found envrc file that is not currently allowed, or allowed file path is different than provided: ${PWD}/${envrc_basename}"
        return $?
      fi
    fi
  fi

  shell::dump_variables --export "$@" | file::write_block --mode 0600 "${envrc_basename}" "${block_name}"

  test "${PIPESTATUS[*]}" = "0 0" || softfail || return $?
  
  direnv allow || softfail || return $?
)
