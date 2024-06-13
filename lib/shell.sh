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

shell::with() (
  local call_array=()

  while [ "$#" -gt 0 ]; do
    case "$1" in
      --)
        shift
        break
        ;;
      *)
        call_array+=("$1")
        shift
        ;;
    esac
  done

  "${call_array[@]}"
  softfail --unless-good --exit-status $? || return $?

  "$@"
)

shell::dump_variables() {
  local prefix

  while [ "$#" -gt 0 ]; do
    case "$1" in
      -e|--export)
        prefix="export "
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

  local list_item; for list_item in "$@"; do
    if [ -n "${!list_item:-}" ]; then
      echo "${prefix:-}$(printf "%q=%q" "${list_item}" "${!list_item}")"
    fi
  done
}

# shellcheck disable=SC2016
shell::enable_trace() {
  PS4='+${BASH_SUBSHELL} ${BASH_SOURCE:+"${BASH_SOURCE}:${LINENO}: "}${FUNCNAME[0]:+"in \`${FUNCNAME[0]}'"'"' "}** '
  set -o xtrace
}

shell::assign_and_mark_for_export() {
  # -g global variable scope
  # -x export
  declare -gx "$1"="$2"
}

shell::related_cd() {
  local self_dir; self_dir="$(dirname "${BASH_SOURCE[1]}")" || softfail || return $?

  cd "${self_dir}" || softfail || return $?

  if [ -n "${1:-}" ]; then
    cd "$1" || softfail || return $?
  fi
}
