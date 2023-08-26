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

# log::test() {
#   # 1356
#   log::error log::error
#   log::warning log::warning
#   log::notice log::notice
#   log::success log::success
# }

log::error() {
  local message="$1"
  log::message --foreground-color 1 "${message}" >&2
}

log::warning() {
  local message="$1"
  log::message --foreground-color 3 "${message}" >&2
}

log::notice() {
  local message="$1"
  log::message --foreground-color 6 "${message}" 
}

log::success() {
  local message="$1"
  log::message --foreground-color 5 "${message}"
}

log::message() {
  local foreground_color=""
  local background_color=""
  local message=""

  while [[ "$#" -gt 0 ]]; do
    case $1 in
    -f|--foreground-color)
        test -t 1 && foreground_color="$(tput setaf "$2" 2>/dev/null)" || foreground_color=""
      shift; shift
      ;;
    -b|--background-color)
      test -t 1 && background_color="$(tput setab "$2" 2>/dev/null)" || background_color=""
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

  local reset_attrs; test -t 1 && reset_attrs="$(tput sgr 0 2>/dev/null)" || reset_attrs=""

  echo "${foreground_color}${background_color}${message}${reset_attrs}"
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
