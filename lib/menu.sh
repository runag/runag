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

menu::select_and_run() {
  local commands_list=()

  if ! [ -t 0 ] || ! [ -t 1 ]; then
    softfail "Menu was called while not in terminal"
    return $?
  fi

  local item
  
  for item in "$@"; do
    if ! { [ -z "${item}" ] || [[ "${item}" =~ ^\# ]]; }; then
      commands_list+=("${item}")
    fi
  done

  menu::display_menu "$@" | less -eFKrWX --mouse --wheel-lines 6
  test "${PIPESTATUS[*]}" = "0 0" || softfail || return $?

  local input_text read_status
  IFS="" read -p "${PS3:-"Please select number: "}" -e -r input_text
  read_status=$?

  if [ ${read_status} != 0 ]; then
    if [ ${read_status} = 1 ] && [ -z "${input_text}" ]; then
      echo "cancelled" >&2
      exit 0
    else
      softfail "Read failed (${read_status})"
      return $?
    fi
  fi

  if [ "${input_text}" = "" ] || [ "${input_text}" = "q" ]; then
    echo "cancelled" >&2
    exit 0
  fi

  if ! [[ "${input_text}" =~ ^[0-9]+$ ]]; then
    softfail "Please select number"
    return $?
  fi

  if [ -z "${commands_list[$((input_text-1))]:+x}" ]; then
    softfail "Selected number is not in the list"
    return $?
  fi

  local selected_item="${commands_list[$((input_text-1))]}"

  # I use "test" instead of "|| fail" here in case if someone wants
  # to use "set -o errexit" in their functions

  eval "${selected_item}"
  softfail_unless_good "Error performing ${selected_item}" $? || return $?

  log::success "Done: ${selected_item}"
  return 0
}

menu::display_menu() {
  local color_a; color_a="$(terminal::color 13)" || softfail || return $?
  local color_a_slight_accent; color_a_slight_accent="$(terminal::color 13)" || softfail || return $?
  local color_a_notable_accent; color_a_notable_accent="$(terminal::color 0 5)" || softfail || return $?
  
  local color_b; color_b="$(terminal::color 15)" || softfail || return $?
  local color_b_slight_accent; color_b_slight_accent="$(terminal::color 15 8)" || softfail || return $?
  local color_b_notable_accent; color_b_notable_accent="$(terminal::color 15 8)" || softfail || return $?

  local header_color; header_color="$(terminal::color 14)" || softfail || return $?
  local comment_color; comment_color="$(terminal::color 10)" || softfail || return $?
  local default_color; default_color="$(terminal::default_color)" || softfail || return $?

  local index=1
  local item
  local current_color=""
  local current_color_slight_accent=""
  local current_color_notable_accent=""
  local endline_sticker=""

  for item in "$@"; do
    if [ -z "${item}" ]; then
      echo ""
      current_color=""

    elif [[ "${item}" =~ ^\# ]]; then

      if [[ "${item}" =~ ^\#\# ]]; then
        echo ""
        echo "  ${header_color}### ${item:2}${default_color}"
        echo ""
      elif [[ "${item}" =~ ^\#\/ ]]; then
        echo "  ${comment_color}> ${item:2}${default_color}"
      else
        echo ""
        echo "  ${header_color}## ${item:1}${default_color}"
        echo ""
      fi
      current_color=""

    else
      if [ "${current_color}" = "${color_a}" ]; then
        current_color="${color_b}"
        current_color_slight_accent="${color_b_slight_accent}"
        current_color_notable_accent="${color_b_notable_accent}"
      else
        current_color="${color_a}"
        current_color_slight_accent="${color_a_slight_accent}"
        current_color_notable_accent="${color_a_notable_accent}"
      fi

      if [ ${#item} -gt 80 ]; then
        endline_sticker=" ${current_color_notable_accent} #$((index))${default_color}"
      else
        endline_sticker=""
      fi

      echo "  ${current_color_slight_accent} $((index)))${default_color} ${current_color}${item}${default_color}${endline_sticker}"

      ((index+=1))
    fi
  done

  echo ""
}
