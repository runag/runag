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

# foo || fail ["error message" [<error code>]]
# foo || fail-with <error code>
#
# foo || return
# foo || softfail ["error message" [<error code>]] || return
#
# foo || softfail || return <error code>
# foo || softfail-with <error code> || return

fail() {
  softfail::internal "$@"
  exit
}

fail-with() {
  softfail::internal "Abnormal termination" "$1"
  exit
}

softfail() {
  softfail::internal "$@"
}

softfail-with() {
  softfail::internal "Abnormal termination" "$1"
}

softfail::internal() {
  local exitStatus="${2:-0}"

  log::error "${1:-"Abnormal termination"}" || echo "Sopka: Unable to log error" >&2

  # making stack trace inside softfail::internal, we dont want to display fail() or softfail() internals in trace
  # so here we start from i=2 (instead of normal i=1) to skip first line of stack trace
  local i endAt=$((${#BASH_LINENO[@]}-1))
  for ((i=2; i<=endAt; i++)); do
    log::error "  ${BASH_SOURCE[${i}]}:${BASH_LINENO[$((i-1))]}: in \`${FUNCNAME[${i}]}'" || echo "Sopka: Unable to log stack trace" >&2
  done

  if [ -n "${exitStatus##*[!0-9]*}" ] && [ "${exitStatus}" != 0 ]; then
    return "${exitStatus}"
  fi

  return 1
}
