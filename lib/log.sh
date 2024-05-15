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

# colors:
# 1  3  5  6 - don't looks good in dark mode
# 9 11 14 13 - looks good in dark mode, looks good in light only with bold

# log::test() {
#   log::error log::error
#   log::warning log::warning
#   log::notice log::notice
#   log::success log::success
# }

log::error() {
  local message="${1:-"(empty log message)"}"
  if [ -t 2 ]; then
    echo "$(printf "setaf 9\nbold" | tput -S 2>/dev/null)${message}$(tput sgr 0 2>/dev/null)" >&2
  else
    echo "[ERROR] ${message}" >&2
  fi
}

log::warning() {
  local message="${1:-"(empty log message)"}"
  if [ -t 2 ]; then
    echo "$(printf "setaf 11\nbold" | tput -S 2>/dev/null)${message}$(tput sgr 0 2>/dev/null)" >&2
  else
    echo "[WARNING] ${message}" >&2
  fi
}

log::notice() {
  local message="${1:-"(empty log message)"}"
  if [ -t 2 ]; then
    echo "$(printf "setaf 14\nbold" | tput -S 2>/dev/null)${message}$(tput sgr 0 2>/dev/null)" >&2
  else
    echo "[NOTICE] ${message}" >&2
  fi
}

log::success() {
  local message="${1:-"(empty log message)"}"
  if [ -t 2 ]; then
    echo "$(printf "setaf 13\nbold" | tput -S 2>/dev/null)${message}$(tput sgr 0 2>/dev/null)" >&2
  else
    echo "[SUCCESS] ${message}" >&2
  fi
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
$(declare -f log::elapsed_time)
SHELL
}
