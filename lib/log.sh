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

log::elapsed_time() {
  echo "Elapsed time: $((SECONDS / 3600))h$(((SECONDS % 3600) / 60))m$((SECONDS % 60))s"
}

log::error() {
  local message="$1"
  log::with_color "${message}" 9 >&2
}

log::warning() {
  local message="$1"
  log::with_color "${message}" 11 >&2
}

log::notice() {
  local message="$1"
  log::with_color "${message}" 14
}

log::success() {
  local message="$1"
  log::with_color "${message}" 10
}

log::with_color() {
  local message="$1"
  local foreground_color="$2"
  local background_color="${3:-}"

  local color_seq="" default_color_seq=""
  if [ -t 1 ]; then
    color_seq="$(terminal::color "${foreground_color}" "${background_color:-}")" || echo "Sopka: Unable to get terminal sequence from tput ($?)" >&2
    default_color_seq="$(terminal::default_color)" || echo "Sopka: Unable to get terminal sequence from tput ($?)" >&2
  fi

  echo "${color_seq}${message}${default_color_seq}"
}

log::error_trace() {
  local message="${1:-""}"
  local start_trace_from="${2:-1}"

  if [ -n "${message}" ]; then
    log::error "${message}" || echo "Sopka: Unable to log error: ${message}" >&2
  fi

  local line i end_at=$((${#BASH_LINENO[@]}-1))
  for ((i=start_trace_from; i<=end_at; i++)); do
    line="${BASH_SOURCE[${i}]}:${BASH_LINENO[$((i-1))]}: in \`${FUNCNAME[${i}]}'"
    log::error "  ${line}" || echo "Sopka: Unable to log stack trace: ${line}" >&2
  done
}
