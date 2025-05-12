#!/usr/bin/env bash

#  Copyright 2012-2025 Runag project contributors
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
  # Red
  [ -t 2 ] && printf "%s\n" "$(printf "setaf 9\nbold" | tput -S 2>/dev/null)${*:-"Log message missing."}$(tput sgr 0 2>/dev/null)" >&2 ||
  printf "[ERROR] %s\n" "${*:-"Log message missing."}" >&2
}

log::warning() {
  # Yellow
  [ -t 2 ] && printf "%s\n" "$(printf "setaf 11\nbold" | tput -S 2>/dev/null)${*:-"Log message missing."}$(tput sgr 0 2>/dev/null)" >&2 ||
  printf "[WARNING] %s\n" "${*:-"Log message missing."}" >&2
}

log::notice() {
  # Cyan/light blue
  [ -t 2 ] && printf "%s\n" "$(printf "setaf 14\nbold" | tput -S 2>/dev/null)${*:-"Log message missing."}$(tput sgr 0 2>/dev/null)" >&2 ||
  printf "[NOTICE] %s\n" "${*:-"Log message missing."}" >&2
}

log::success() {
  # Magenta/light purple
  [ -t 2 ] && printf "%s\n" "$(printf "setaf 13\nbold" | tput -S 2>/dev/null)${*:-"Log message missing."}$(tput sgr 0 2>/dev/null)" >&2 ||
  printf "[SUCCESS] %s\n" "${*:-"Log message missing."}" >&2
}

log::elapsed_time() {
  log::notice "Elapsed time: $((SECONDS / 3600))h$(((SECONDS % 3600) / 60))m$((SECONDS % 60))s"
}

# colors:
# 1  3  5  6 - don't looks good in dark mode
# 9 11 14 13 - looks good in dark mode, looks good in light only with bold

log::colors() {
  local i; for i in {0..15}; do 
    printf "%s%-14s%s%s%-14s%s\n" \
      "$(tput setaf "${i}")" "tput setaf ${i}" "$(tput sgr0)" \
      "$(tput setab "${i}")" "tput setab ${i}" "$(tput sgr0)" >&2
  done
}
