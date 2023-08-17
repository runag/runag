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
  local foreground_color_seq=""
  local background_color_seq=""
  local message=""

  while [[ "$#" -gt 0 ]]; do
    case $1 in
    -f|--foreground-color)
      if [ -t 1 ]; then
        foreground_color_seq="$(terminal::color --foreground "$2")" || echo "Unable to obtain terminal::color ($?)" >&2
      fi
      shift; shift
      ;;
    -b|--background-color)
      if [ -t 1 ]; then
        background_color_seq="$(terminal::color --background "$2")" || echo "Unable to obtain terminal::color ($?)" >&2
      fi
      shift; shift
      ;;
    -*)
      echo "Unknown argument for log::message: $1" >&2
      shift
      message="$*"
      break
      ;;
    *)
      message="$1"
      break
      ;;
    esac
  done

  if [ -z "${message}" ]; then
    message="(empty log message)"
  fi

  local default_color_seq=""
  if [ -t 1 ]; then
    default_color_seq="$(terminal::default_color)" || echo "Unable to obtain terminal::color ($?)" >&2
  fi

  echo "${foreground_color_seq}${background_color_seq}${message}${default_color_seq}"
}

log::elapsed_time() {
  log::notice "Elapsed time: $((SECONDS / 3600))h$(((SECONDS % 3600) / 60))m$((SECONDS % 60))s"
}

log::function_sources() {
  cat <<SHELL || softfail || return $?
$(declare -f log::error)
$(declare -f log::warning)
$(declare -f log::notice)
$(declare -f log::success)
$(declare -f log::message)
$(declare -f log::elapsed_time)
SHELL
}
