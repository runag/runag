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

sopkafile_menu::necessary() {
  if [ -n "${1:-}" ] && [[ ! "${OSTYPE}" =~ ^"$1" ]]; then
    return 1
  fi
  [ -t 0 ] && [ -t 1 ]
}

sopkafile_menu::add() {
  local command_string; printf -v command_string " %q" "$@" || softfail "Unable to produce command string" || return $?
  SOPKAFILE_MENU+=("${command_string:1}")
}

sopkafile_menu::add_raw() {
  SOPKAFILE_MENU+=("$1")
}

sopkafile_menu::add_delimiter() {
  SOPKAFILE_MENU+=("")
}

sopkafile_menu::add_header() {
  SOPKAFILE_MENU+=("#$1")
}

sopkafile_menu::add_subheader() {
  SOPKAFILE_MENU+=("##$1")
}

sopkafile_menu::add_note() {
  SOPKAFILE_MENU+=("#/$1")
}

sopkafile_menu::display() {
  if [ -z ${SOPKAFILE_MENU:+x} ]; then
    softfail "Menu is empty"
    return $?
  fi
  menu::select_and_run "${SOPKAFILE_MENU[@]}"
  softfail_unless_good_code $?
}

sopkafile_menu::present() {
  test -n "${SOPKAFILE_MENU:+x}"
}

sopkafile_menu::clear() {
  SOPKAFILE_MENU=()
}

sopkafile_menu::add_defaults() {
  sopkafile_menu::add_header "Same menu with certain flags set" || softfail || return $?

  sopkafile_menu::add task::with_update_secrets sopkafile_menu::display || softfail || return $?
  sopkafile_menu::add task::with_verbose_task sopkafile_menu::display || softfail || return $?

  if [ -d "${HOME}/.sopka" ]; then
    sopkafile_menu::add_header "Sopka and sopkafiles" || softfail || return $?
    
    sopkafile_menu::add sopka::create_or_update_offline_install || softfail || return $?
    sopkafile_menu::add sopka::update || softfail || return $?
  fi
}
