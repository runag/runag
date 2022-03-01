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
  local foreground="$1"
  local background="${2:-}"

  local amount

  if command -v tput >/dev/null && amount="$(tput colors 2>/dev/null)" && [[ "${amount}" =~ ^[0-9]+$ ]]; then
    if [[ "${foreground}" =~ ^[0-9]+$ ]] && [ "${amount}" -ge "${foreground}" ]; then
      tput setaf "${foreground}" || echo "Sopka: Unable to get terminal sequence from tput ($?)" >&2
    fi

    if [[ "${background}" =~ ^[0-9]+$ ]] && [ "${amount}" -ge "${background}" ]; then
      tput setab "${background}" || echo "Sopka: Unable to get terminal sequence from tput ($?)" >&2
    fi
  fi
}

terminal::default_color() {
  if command -v tput >/dev/null; then
    tput sgr 0 || echo "Sopka: Unable to get terminal sequence from tput ($?)" >&2
  fi
}
