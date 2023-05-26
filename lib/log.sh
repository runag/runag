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

log::elapsed_time() {
  log::notice "Elapsed time: $((SECONDS / 3600))h$(((SECONDS % 3600) / 60))m$((SECONDS % 60))s"
}

log::error() {
  local message="$1"
  log::message --foreground-color 9 "${message}" >&2
}

log::warning() {
  local message="$1"
  log::message --foreground-color 11 "${message}" >&2
}

log::notice() {
  local message="$1"
  log::message --foreground-color 14 "${message}" 
}

log::success() {
  local message="$1"
  log::message --foreground-color 10 "${message}"
}

log::message() {
  local foreground_color
  local background_color

  while [[ "$#" -gt 0 ]]; do
    case $1 in
    -f|--foreground-color)
      foreground_color="$2"
      shift; shift
      ;;
    -b|--background-color)
      background_color="$2"
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

  local message="$1"

  local color_seq="" default_color_seq=""
  if [ -t 1 ]; then
    color_seq="$(terminal::color --foreground "${foreground_color:-}" --background "${background_color:-}")" || echo "Unable to get terminal sequence from tput ($?)" >&2
    default_color_seq="$(terminal::default_color)" || echo "Unable to get terminal sequence from tput ($?)" >&2
  fi

  echo "${color_seq}${message}${default_color_seq}"
}

log::trace() {
  local trace_start=1

  while [[ "$#" -gt 0 ]]; do
    case $1 in
    -s|--start)
      trace_start="$2"
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

  local message="${1:-""}"

  if [ -n "${message}" ]; then
    log::error "${message}" || echo "Unable to log error: ${message}" >&2
  fi

  local line i trace_end=$((${#BASH_LINENO[@]}-1))
  for ((i=trace_start; i<=trace_end; i++)); do
    line="${BASH_SOURCE[${i}]}:${BASH_LINENO[$((i-1))]}: in \`${FUNCNAME[${i}]}'"
    log::error "  ${line}" || echo "Unable to log stack trace: ${line}" >&2
  done
}

log::function_sources() {
  cat <<SHELL || softfail || return $?
$(declare -f log::elapsed_time)
$(declare -f log::error)
$(declare -f log::warning)
$(declare -f log::notice)
$(declare -f log::success)
$(declare -f log::message)
$(declare -f log::trace)
SHELL
}
