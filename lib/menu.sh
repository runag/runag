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

  # shellcheck disable=SC2034
  local RUNAG_MENU_REFRAIN_FROM_SUCCESS_LOGGING

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

  local prompt_color; test -t 1 && prompt_color="$(tput setaf 3 2>/dev/null)" || prompt_color=""
  local reset_attrs; test -t 1 && reset_attrs="$(tput sgr 0 2>/dev/null)" || reset_attrs=""

  menu::display_menu "$@" | less -eFKrWX --mouse --wheel-lines 6
  test "${PIPESTATUS[*]}" = "0 0" || softfail || return $?

  local input_text read_status
  IFS="" read -p "${prompt_color}${PS3:-"Please select number: "}${reset_attrs}" -e -r input_text
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

  # Reset SECONDS to get an accurate elapsed time
  SECONDS=0

  # I use "test" instead of "|| fail" here in case if someone wants
  # to use "set -o errexit" in their functions

  eval "${selected_item}"
  softfail --unless-good --exit-status $? "Error performing ${selected_item} ($?)" || return $?

  if [ "${RUNAG_MENU_REFRAIN_FROM_SUCCESS_LOGGING:-}" != true ]; then
    log::success "Done: ${selected_item}"
  fi

  return 0
}

menu::display_menu() {
  # 1 - color a
  # 3 - prompt
  # 5 - header
  # 6 - comment

  local color_a; test -t 0 && color_a="$(tput setaf 1 2>/dev/null)" || color_a=""
  local color_b

  local color_a_accent; test -t 0 && color_a_accent="$(printf "setaf 15\nsetab 1" | tput -S 2>/dev/null)" || color_a_accent=""
  local color_b_accent; test -t 0 && color_b_accent="$(printf "setaf 15\nsetab 8" | tput -S 2>/dev/null)" || color_b_accent=""

  local header_color; test -t 0 && header_color="$(tput setaf 5 2>/dev/null)" || header_color=""
  local comment_color; test -t 0 && comment_color="$(tput setaf 6 2>/dev/null)" || comment_color=""

  local reset_attrs; test -t 0 && reset_attrs="$(tput sgr 0 2>/dev/null)" || reset_attrs=""

  local item index=1
  local current_color
  local current_color_accent
  local endline_sticker
  local last_line_was_header=false

  for item in "$@"; do
    if [ -z "${item}" ]; then
      # delimiter
      echo ""
      current_color=""
      last_line_was_header=false

    elif [[ "${item}" =~ ^\# ]]; then
      # subheader, note, or header

      if [[ "${item}" =~ ^\#\#\  ]]; then
        # header
        echo ""
        echo "  ${header_color}## ${item:3}${reset_attrs}"
        echo ""
        current_color=""
        last_line_was_header=true

      elif [[ "${item}" =~ ^\#\#\#\  ]]; then
        # subheader
        if [ "${last_line_was_header}" != true ]; then
          echo ""
        fi
        echo "  ${header_color}### ${item:4}${reset_attrs}"
        echo ""
        current_color=""
        last_line_was_header=true

      elif [[ "${item}" =~ ^\#\>\  ]]; then
        # note
        echo "   ${comment_color}> ${item:3}${reset_attrs}"
        current_color=""
        last_line_was_header=false
      fi

    else
      # menu item
      if [ "${current_color:-}" = "${color_a}" ]; then
        current_color="${color_b:-}"
        current_color_accent="${color_b_accent}"
      else
        current_color="${color_a}"
        current_color_accent="${color_a_accent}"
      fi

      if [[ "${item}" =~ [^\\]\#([[:digit:]]+)\#$ ]]; then
        local signal_length="${BASH_REMATCH[1]}"
        local signal_message="${item: -$((signal_length+${#signal_length}+2)):${signal_length}}"

        if [[ "${signal_message}" =~ ^\#\*\  ]]; then
          item="${signal_message:3}"
        fi
      fi

      if [ ${#item} -gt 80 ]; then
        endline_sticker=" ${current_color_accent} #$((index))${reset_attrs}"
      else
        endline_sticker=""
      fi

      echo "  ${current_color} $((index))) ${item}${reset_attrs}${endline_sticker}"

      last_line_was_header=false

      ((index+=1))
    fi
  done

  echo ""
}
