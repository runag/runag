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

runagfile_menu::necessary() {
  while [[ "$#" -gt 0 ]]; do
    case $1 in
    -o|--os)
      local os_type="$2"
      if [[ ! "${OSTYPE}" =~ ^"${os_type}" ]]; then
        return 1
      fi
      shift; shift
      ;;
    -*)
      fail "Unknown argument: $1"
      ;;
    *)
      break
      ;;
    esac
  done

  [ -t 0 ] && [ -t 1 ]
}

runagfile_menu::clear() {
  RUNAGFILE_MENU=()
}

runagfile_menu::add() {
  if [ ! -t 0 ] || [ ! -t 1 ]; then
    return
  fi

  local quote=true
  local add_delimiter=false
  local prefix=""
  local postfix=""
  local add_menu=false

  while [[ "$#" -gt 0 ]]; do
    case $1 in
      -o|--os)
        local os_type="$2"
        if [[ ! "${OSTYPE}" =~ ^"${os_type}" ]]; then
          return
        fi
        shift; shift
        ;;
      -r|--raw)
        quote=false
        shift
        ;;
      -d|--delimiter)
        add_delimiter=true
        shift
        ;;
      -h|--header)
        prefix="# "
        quote=false
        shift
        ;;
      -s|--subheader)
        prefix="## "
        quote=false
        shift
        ;;
      -n|--note)
        prefix="#> "
        quote=false
        shift
        ;;
      -c|--comment)
        postfix=" # $2"
        shift; shift
        ;;
      -m|--menu)
        add_menu=true
        shift
        ;;
      -*)
        fail "Unknown argument: $1"
        ;;
      *)
        break
        ;;
    esac
  done

  local operand_string
  if [ "${add_delimiter}" = true ]; then
    operand_string=""
  else
    if [ "${add_menu}" = true ]; then
      set -- runagfile_menu::display_for "$1"::runagfile_menu "${@:2}"
    fi
    if [ "${quote}" = true ]; then
      printf -v operand_string " %q" "$@" || softfail "Unable to produce operand string" || return $?
      operand_string="${operand_string:1}"
    else
      printf -v operand_string " %s" "$@" || softfail "Unable to produce operand string" || return $?
      operand_string="${operand_string:1}"
    fi
  fi

  RUNAGFILE_MENU+=("${prefix}${operand_string}${postfix}")
}

runagfile_menu::display() {
  if ! runagfile_menu::present; then
    softfail "Menu is empty"
    return $?
  fi
  menu::select_and_run "${RUNAGFILE_MENU[@]}"
  softfail_unless_good_code $?
}

runagfile_menu::present() {
  test -n "${RUNAGFILE_MENU:+x}"
}

runagfile_menu::display_for() {(
  runagfile_menu::clear || softfail || return $?
  "$@" || softfail || return $?
  runagfile_menu::display
  softfail_unless_good "Error performing runagfile_menu::display ($?)" $?
)}
