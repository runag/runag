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
    case $1 in
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

shell::export_variables_as_code() {
  local list_item; for list_item in "$@"; do
    if [ -n "${!list_item:-}" ]; then
      echo "export $(printf "%q=%q" "${list_item}" "${!list_item}")"
    fi
  done
}

# shellcheck disable=SC2016
shell::enable_trace() {
  PS4='+${BASH_SUBSHELL} ${BASH_SOURCE:+"${BASH_SOURCE}:${LINENO}: "}${FUNCNAME[0]:+"in \`${FUNCNAME[0]}'"'"' "}** '
  set -o xtrace
}

shell::export_variable() {
  declare -gx "$1"="$2"
}
