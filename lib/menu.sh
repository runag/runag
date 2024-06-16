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

# TODO: return from menu as actionable item
# TODO: screen width overflow limit
# TODO: screen height overflow scroll (how to scroll in case with trailing or leading headers?)
# TODO: keyboard input filter

menu::present() {
  local store_name=DEFAULT

  while [ "$#" -gt 0 ]; do
    case "$1" in
      -s|--store)
        store_name="$2"
        shift; shift
        ;;
      *)
        fail "Unknown argument: $1" # no softfail here!
        ;;
    esac
  done

  declare -n menu_data="RUNAG_MENU_${store_name}"

  [[ -v menu_data ]] && (( ${#menu_data[@]} > 0 ))
}

menu::is_necessary() {
  while [ "$#" -gt 0 ]; do
    case "$1" in
      -o|--os)
        local os_type="$2"
        if [[ ! "${OSTYPE}" =~ ^"${os_type}" ]]; then
          return 1
        fi
        shift; shift
        ;;
      *)
        fail "Unknown argument: $1" # no softfail here!
        ;;
    esac
  done
}

menu::clear() {
  local store_name=DEFAULT

  while [ "$#" -gt 0 ]; do
    case "$1" in
      -s|--store)
        store_name="$2"
        shift; shift
        ;;
      *)
        softfail "Unknown argument: $1" || return $?
        ;;
    esac
  done

  # -g global variable scope
  # -a array
  declare -ga "RUNAG_MENU_${store_name}=()"
}

menu::add() {
  local store_name=DEFAULT
  local menu_item_type="menu-item"

  while [ "$#" -gt 0 ]; do
    case "$1" in
      -s|--store)
        store_name="$2"
        shift; shift
        ;;
      -o|--os)
        if [[ ! "${OSTYPE}" =~ ^"$2" ]]; then
          return
        fi
        shift; shift
        ;;
      -m|--menu)
        menu_item_type="submenu-item"
        shift
        ;;
      *)
        break
        ;;
    esac
  done

  declare -n menu_data="RUNAG_MENU_${store_name}"

  if [[ ! -v menu_data ]]; then
    declare -ga "RUNAG_MENU_${store_name}=()"
  fi

  # I guess I could just assign to an empty undeclared variable but better to init it anyway
  menu_data+=("${menu_item_type}" "$#" "$@")
}

menu::with() (
  local enable_return

  while [ "$#" -gt 0 ]; do
    case "$1" in
      -r|--enable-return)
        enable_return=true
        shift
        ;;
      *)
        break
        ;;
    esac
  done

  menu::clear || softfail || return $?

  "$@"
  softfail --unless-good --exit-status $? "Error performing $1 ($?)" || return $?

  menu::display ${enable_return:+"--enable-return"}
  local command_exit_status=$?

  if [ "${command_exit_status}" = 254 ]; then
    return "${command_exit_status}"
  fi

  softfail --unless-good --exit-status "${command_exit_status}" "Error performing menu::display (${command_exit_status})" || return $?
)

menu::display() {
  local store_name=DEFAULT
  local enable_return=false

  while [ "$#" -gt 0 ]; do
    case "$1" in
      -s|--store)
        store_name="$2"
        shift; shift
        ;;
      -r|--enable-return)
        enable_return=true
        shift
        ;;
      *)
        softfail "Unknown argument: $1" || return $?
        ;;
    esac
  done

  # NOTE: strange transgressive variables Like_This all around!
  # shellcheck disable=SC2178
  declare -n Menu_Data="RUNAG_MENU_${store_name}"

  if [[ ! -v Menu_Data ]]; then
    declare -ga "RUNAG_MENU_${store_name}=()"
  fi

  if [ "${#Menu_Data[@]}" = 0 ]; then
    softfail "Menu is empty"
    return $?
  fi

  # Define colors
  local Prompt_Color=""
  local Color_A=""
  local Color_B=""
  local Color_A_Accent=""
  local Color_B_Accent=""
  local Header_Color=""
  local Comment_Color=""
  local Cursor_Up_Seq
  local Reset_Attrs=""
  local Clear_Line=""
  local Leading_Spacer=" "

  # stdio
  # 0 stdin
  # 1 stdout
  # 2 stderr

  # Color palette
  # 1 - color a
  # 3 - prompt
  # 5 - header
  # 6 - comment

  if [ -t 0 ]; then # stdin (0) is a terminal
    Prompt_Color="$(printf "setaf 11\nbold" | tput -S 2>/dev/null)" || Prompt_Color=""
  fi

  if [ -t 1 ]; then # stdout (1) is a terminal
    Color_A="$(tput setaf 9 2>/dev/null)" || Color_A=""

    Color_A_Accent="$(printf "setaf 15\nsetab 9" | tput -S 2>/dev/null)" || Color_A_Accent=""
    Color_B_Accent="$(printf "setaf 15\nsetab 8" | tput -S 2>/dev/null)" || Color_B_Accent=""

    Header_Color="$(printf "setaf 14\nbold" | tput -S 2>/dev/null)" || Header_Color=""
    Comment_Color="$(printf "setaf 13\nbold" | tput -S 2>/dev/null)" || Comment_Color=""

    Cursor_Up_Seq="$(tput cuu1 2>/dev/null)" || softfail || return $?
  fi

  if [ -t 0 ] || [ -t 1 ]; then # stdin (0) or stdout (1) is a terminal
    Reset_Attrs="$(tput sgr 0 2>/dev/null)" || softfail || return $?
    Clear_Line="$(tput el 2>/dev/null)" || softfail || return $?
  fi
  

  # Set positions
  local Item_Position=undefined
  local Section_Position=undefined

  local First_Render=true
  local Lines_Drawn

  # Flags
  local Non_Interactive=false

  # Exit actions
  local Should_Perform_Command
  local Should_Exit
  local Should_Return
  local Should_Enter

  local Selected_Command
  local Selected_Command_Type

  # Exit status
  local command_exit_status

  if ! [ -t 0 ] || ! [ -t 1 ]; then # stdin (0) or stdout (1) are not a terminal
    Non_Interactive=true
    Leading_Spacer=""
    menu::render || softfail || return $?
    return 0
  fi

  while : ; do
    menu::render || softfail || return $?

    Should_Perform_Command=false
    Should_Exit=false
    Should_Return=false
    Should_Enter=false

    menu::read_input || softfail || return $?

    if [ "${enable_return}" = true ] && [ "${Should_Return}" = true ]; then
      return 254
    elif [ "${Should_Exit}" = true ]; then
      return 0
    elif [ "${Should_Perform_Command}" = true ] || { [ "${Should_Enter}" = true ] && [ "${Selected_Command_Type}" = "submenu-item" ]; }; then

      if [ "${Selected_Command_Type}" = "submenu-item" ]; then
        printf "\n. . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . .\n\n"
        menu::with --enable-return "${Selected_Command[@]}"
        command_exit_status=$?
        if [ "${command_exit_status}" = 254 ]; then
          First_Render=true
          printf "\n. . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . .\n\n"
          continue
        fi
      else
        echo $'\n'"${Prompt_Color}> ${Selected_Command[*]}${Reset_Attrs}" 
        "${Selected_Command[@]}"
        command_exit_status=$?
      fi

      # Use "test" instead of "|| fail" here in case if someone wants
      # to use "set -o errexit" in their functions
      softfail --unless-good --exit-status "${command_exit_status}" "Error performing ${Selected_Command[0]} (${command_exit_status})" || return $?

      # Display "Done" message
      if [ -t 1 ]; then
        log::success "Done: ${Selected_Command[*]}"
      fi

      return 0
    fi
  done
}

#           |             |     |     |     |           |
# 0         | 1           | 2   | 3   | 4   | 5         | 6
# 4         | 5           | 6   | 7   | 8   | 9         | 10
# op        | item_length |     |     |     | op        | item_length
# menu-item | 3           | foo | bar | qux | menu-item |

# main_pointer 4
# item_pointer 7
# item_length  3

menu::render() {
  local main_pointer
  local item_pointer

  local comment
  local is_command
  local item_length
  local item_type
  
  local command
  local command_display_prefix

  local Current_Color
  local current_color_accent

  local Meta_Lines=()
  local meta_line_pointer

  local selection_marker
  local enter_marker

  local current_item_index=undefined
  local current_section_index=undefined
  local current_line_color

  if [ "${First_Render}" != true ]; then
    if [ -t 1 ]; then # stdout (1) is a terminal
      for (( ; Lines_Drawn > 0; Lines_Drawn--)); do
        printf "%s" "${Cursor_Up_Seq}"
      done
    fi
  else
    First_Render=false
  fi

  Lines_Drawn=0

  for (( main_pointer = 0; main_pointer < ${#Menu_Data[@]}; main_pointer++ )); do 
    if [ "${Menu_Data[main_pointer]}" = "menu-item" ] || [ "${Menu_Data[main_pointer]}" = "submenu-item" ]; then
      comment=""
      is_command=true
      item_length="${Menu_Data[main_pointer + 1]}"
      item_type="${Menu_Data[main_pointer]}"

      for (( item_pointer = main_pointer + 2; item_pointer <= main_pointer + item_length + 1; item_pointer++ )); do 
        case "${Menu_Data[item_pointer]}" in
          -h|--header)
            (( item_pointer += 1 ))
            is_command=false
            Meta_Lines+=("header" "${Menu_Data[item_pointer]}")
            ;;
          -n|--note)
            (( item_pointer += 1 ))
            is_command=false
            Meta_Lines+=("note" "${Menu_Data[item_pointer]}")
            ;;
          -c|--comment)
            (( item_pointer += 1 ))
            comment="${Menu_Data[item_pointer]}"
            ;;
          -*)
            softfail "Unknown argument: ${Menu_Data[item_pointer]}" || return $?
            ;;
          *)
            break
            ;;
        esac
      done

      if [ "${is_command}" = true ] && (( item_pointer <= main_pointer + item_length + 1 )); then

        command=("${Menu_Data[@]:item_pointer:((item_length-(item_pointer-main_pointer-2)))}")

        if [ "${current_item_index}" = undefined ]; then
          current_item_index=0
        fi

        if [ "${current_section_index}" = undefined ]; then
          current_section_index=0
        fi

        if (( current_item_index > 0 && ${#Meta_Lines[@]} > 0)); then
          for (( meta_line_pointer = 0; meta_line_pointer < ${#Meta_Lines[@]}; meta_line_pointer+=2 )); do
            if [ "${Meta_Lines[meta_line_pointer]}" = "header" ]; then
              (( current_section_index += 1 ))
              break
            fi
          done
        fi

        menu::render::meta_lines "${current_item_index}" || softfail || return $?

        if [ "${Current_Color:-}" = "${Color_A}" ]; then
          Current_Color="${Color_B:-}"
          current_color_accent="${Color_B_Accent}"
        else
          Current_Color="${Color_A}"
          current_color_accent="${Color_A_Accent}"
        fi

        if [ "${Item_Position}" = undefined ] && [ "${Section_Position}" = undefined ]; then
          Item_Position=current_item_index
          Section_Position=current_section_index

        elif [ "${Item_Position}" = undefined ] && [ "${Section_Position}" = "${current_section_index}" ]; then
          (( Item_Position = current_item_index ))

        elif [ "${Section_Position}" = undefined ] && [ "${Item_Position}" = "${current_item_index}" ]; then
          (( Section_Position = current_section_index ))
        fi

        enter_marker=""

        if [ "${Non_Interactive}" != true ] && [ "${Item_Position}" = "${current_item_index}" ]; then
          Selected_Command=("${command[@]}")
          Selected_Command_Type="${item_type}"

          selection_marker+="${Current_Color}!${Reset_Attrs}"
          current_line_color="${current_color_accent}"

          if [ "${item_type}" = "submenu-item" ]; then
            enter_marker=" ${Current_Color}# -->${Reset_Attrs}"
          fi
        else
          selection_marker=""
          current_line_color="${Current_Color}"
        fi

        if [ "${Menu_Data[main_pointer]}" = "submenu-item" ]; then
          command_display_prefix="menu::with "
        else
          command_display_prefix=""
        fi

        # echo -n "$(date +%N)"
        echo "${Clear_Line}${selection_marker}${Leading_Spacer}${current_line_color}${command_display_prefix}${command[*]}${Reset_Attrs}${comment:+" ${Comment_Color}#  ${comment}${Reset_Attrs}"}${enter_marker}"

        (( Lines_Drawn+=1 ))
        (( current_item_index+=1 ))
      fi

      (( main_pointer += item_length + 1 ))
    else
      softfail "Unknown menu operation" || return $?
    fi
  done

  menu::render::meta_lines "${current_item_index}" || softfail || return $?

  # echo "${Clear_Line}Item_Position: ${Item_Position}, Section_Position: ${Section_Position}, current_item_index: ${current_item_index}, current_section_index: ${current_section_index}"; ((Lines_Drawn+=1))

  
  if [ "${Non_Interactive}" != true ]; then
    if [ "${Item_Position}" = undefined ]; then
      if [ "${Section_Position}" != undefined ] && [ "${current_section_index}" != undefined ]; then
        if (( Section_Position < 0 )); then
          (( Section_Position = current_section_index ))
          menu::render
        elif (( Section_Position >= current_section_index )); then
          Item_Position=0
          Section_Position=0
          menu::render
        fi
      fi
    elif [ "${current_item_index}" != undefined ]; then
      if (( Item_Position < 0 )); then
        (( Item_Position = current_item_index - 1 ))
        menu::render
      elif (( Item_Position >= current_item_index )); then
        Item_Position=0
        Section_Position=0
        menu::render
      fi
    fi
  fi
}

menu::render::meta_lines() {
  local current_item_index="$1"
  local meta_line_pointer
  local spacer_required=false

  if (( ${#Meta_Lines[@]} > 0)); then
    if [ "${current_item_index}" != undefined ] && [ "${current_item_index}" -gt 0 ]; then
      spacer_required=true
    fi
    for (( meta_line_pointer = 0; meta_line_pointer < ${#Meta_Lines[@]}; meta_line_pointer+=2 )); do
      if [ "${Meta_Lines[meta_line_pointer]}" = "header" ]; then
        if [ "${spacer_required}" = true ]; then
          echo "${Clear_Line}"
          (( Lines_Drawn += 1 ))
          spacer_required=false
        fi
        echo "${Clear_Line}${Header_Color}${Leading_Spacer}# ${Meta_Lines[meta_line_pointer+1]}${Reset_Attrs}"

      elif [ "${Meta_Lines[meta_line_pointer]}" = "note" ]; then
        echo "${Clear_Line}${Comment_Color}${Leading_Spacer}# -- ${Meta_Lines[meta_line_pointer+1]}${Reset_Attrs}"
        spacer_required=true
      fi
      (( Lines_Drawn+=1 ))
    done
    Current_Color=""
    Meta_Lines=()
  fi

}

# https://en.wikipedia.org/wiki/Escape_sequence#Keyboard
# https://en.wikipedia.org/wiki/ANSI_escape_code#Terminal_input_sequences
# https://tldp.org/HOWTO/Bash-Prompt-HOWTO/x405.html
# https://www.manpagez.com/man/5/terminfo/

menu::read_input() {
  local input_text
  local read_status

  # -n number of chars
  # -p prompt
  # -r backslash will not escape
  # -s silent
  # -t timeout

  # -p "${Prompt_Color}${PS3:-"Please select: "}${Reset_Attrs}" 

  IFS="" read -n 1 -r -s input_text || softfail "Read failed: $?" || return $?

  if [ "${input_text}" = $'\004' ]; then # ^d was pressed
    Should_Exit=true
  fi

  if [ "${input_text}" = $'\033' ]; then # (0x1B) escape sequence
    # -n 5 -- is a longest tail of escape sequence I guess
    # -t 0.01 -- see "not many doubles" below
    IFS="" read -n 5 -r -s -t 0.01 input_text
    read_status=$?

    if [ ${read_status} -gt 128 ]; then # timeout (greater than 128 is from the bash man page)
      # zero input with timeout is a heuristic to determine that Esc was pressed
      if [ -z "${input_text}" ]; then
        Should_Exit=true
      fi
    elif [ ${read_status} != 0 ]; then
      softfail "Read failed: ${read_status}"
      return $?
    fi

    case "${input_text}" in
      "[5~" | "[1;5A") # PgUp, ^Up
        if [ "${Section_Position}" != undefined ]; then
          Item_Position=undefined
          (( Section_Position -= 1 )) || true
        fi
        ;;
      "[6~" | "[1;5B") # PgDn, ^Down
        if [ "${Section_Position}" != undefined ]; then
          Item_Position=undefined
          (( Section_Position += 1 ))
        fi
        ;;
      "[A")  # Up
        if [ "${Item_Position}" != undefined ]; then
          ((Item_Position-=1))
          Section_Position=undefined
        fi
        ;;
      "[B")  # Down
        if [ "${Item_Position}" != undefined ]; then
          ((Item_Position+=1))
          Section_Position=undefined
        fi
        ;;
      "[C")  # Right
        if [ "${Item_Position}" != undefined ]; then
          Should_Enter=true
        fi
        ;;
      "[D")  # Left
        Should_Return=true
        ;;
      "[F")  # End
        if [ "${Item_Position}" != undefined ]; then
          Item_Position=-1
          Section_Position=undefined
        fi
        ;;
      "[H")  # Home
        if [ "${Item_Position}" != undefined ]; then
          Item_Position=0
          Section_Position=0
        fi
        ;;
    esac

  # elif [ "${input_text}" = $'\177' ]; then
    # backspace

  elif [ "${input_text}" = "" ]; then
    if [ "${Item_Position}" != undefined ]; then
      Should_Perform_Command=true
    fi
  fi
}
