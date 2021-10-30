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

log::elapsed-time() {
  echo "Elapsed time: $((SECONDS / 3600))h$(((SECONDS % 3600) / 60))m$((SECONDS % 60))s"
}

log::error() {
  local message="$1"
  log::with-color "${message}" 9 >&2
}

log::warning() {
  local message="$1"
  log::with-color "${message}" 11 >&2
}

log::notice() {
  local message="$1"
  log::with-color "${message}" 14
}

log::success() {
  local message="$1"
  log::with-color "${message}" 10
}

log::with-color() {
  local message="$1"
  local foregroundColor="$2"
  local backgroundColor="${3:-}"

  local colorSeq="" defaultColorSeq=""
  if [ -t 1 ]; then
    colorSeq="$(terminal::color "${foregroundColor}" "${backgroundColor:-}")" || echo "Sopka: Unable to get terminal sequence from tput ($?)" >&2
    defaultColorSeq="$(terminal::default-color)" || echo "Sopka: Unable to get terminal sequence from tput ($?)" >&2
  fi

  echo "${colorSeq}${message}${defaultColorSeq}"
}

log::error-trace() {
  local message="${1:-""}"
  local startTraceFrom="${2:-1}"

  if [ -n "${message}" ]; then
    log::error "${message}" || echo "Sopka: Unable to log error: ${message}" >&2
  fi

  local line i endAt=$((${#BASH_LINENO[@]}-1))
  for ((i=startTraceFrom; i<=endAt; i++)); do
    line="${BASH_SOURCE[${i}]}:${BASH_LINENO[$((i-1))]}: in \`${FUNCNAME[${i}]}'"
    log::error "  ${line}" || echo "Sopka: Unable to log stack trace: ${line}" >&2
  done
}
