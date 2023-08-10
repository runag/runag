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

terminal::have_16_colors() {
  local amount
  command -v tput >/dev/null && amount="$(tput colors 2>/dev/null)" && [[ "${amount}" =~ ^[0-9]+$ ]] && [ "${amount}" -ge 16 ]
}

terminal::print_color_table() {
  for i in {0..16..1}; do 
    echo "$(tput setaf "${i}")tput setaf ${i}$(tput sgr 0)"
  done

  for i in {0..16..1}; do 
    echo "$(tput setab "${i}")tput setab ${i}$(tput sgr 0)"
  done
}

terminal::color() {
  local foreground_color=""
  local background_color=""

  while [[ "$#" -gt 0 ]]; do
    case $1 in
    -f|--foreground)
      foreground_color="$2"
      shift; shift
      ;;
    -b|--background)
      background_color="$2"
      shift; shift
      ;;
    -*)
      echo "Unknown argumen for terminal::color: $1" >&2
      return 1
      ;;
    *)
      break
      ;;
    esac
  done

  local amount

  if command -v tput >/dev/null && amount="$(tput colors 2>/dev/null)" && [[ "${amount}" =~ ^[0-9]+$ ]]; then
    if [[ "${foreground_color:-}" =~ ^[0-9]+$ ]] && [ "${amount}" -ge "${foreground_color:-}" ]; then
      tput setaf "${foreground_color}" || { echo "Unable to get terminal sequence from tput in terminal::color ($?)" >&2; return 1; }
    fi

    if [[ "${background_color:-}" =~ ^[0-9]+$ ]] && [ "${amount}" -ge "${background_color:-}" ]; then
      tput setab "${background_color}" || { echo "Unable to get terminal sequence from tput in terminal::color ($?)" >&2; return 1; }
    fi
  fi
}

terminal::default_color() {
  if command -v tput >/dev/null; then
    tput sgr 0 || { echo "Unable to get terminal sequence from tput in terminal::color ($?)" >&2; return 1; }
  fi
}

terminal::function_sources() {
  cat <<SHELL || softfail || return $?
$(declare -f terminal::have_16_colors)
$(declare -f terminal::print_color_table)
$(declare -f terminal::color)
$(declare -f terminal::default_color)
SHELL
}
