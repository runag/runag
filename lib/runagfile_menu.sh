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
  if [ -n "${1:-}" ] && [[ ! "${OSTYPE}" =~ ^"$1" ]]; then
    return 1
  fi
  [ -t 0 ] && [ -t 1 ]
}

runagfile_menu::add() {
  local command_string; printf -v command_string " %q" "$@" || softfail "Unable to produce command string" || return $?
  RUNAGFILE_MENU+=("${command_string:1}")
}

runagfile_menu::add_raw() {
  RUNAGFILE_MENU+=("$1")
}

runagfile_menu::add_delimiter() {
  RUNAGFILE_MENU+=("")
}

runagfile_menu::add_header() {
  RUNAGFILE_MENU+=("#$1")
}

runagfile_menu::add_subheader() {
  RUNAGFILE_MENU+=("##$1")
}

runagfile_menu::add_note() {
  RUNAGFILE_MENU+=("#/$1")
}

runagfile_menu::display() {
  if [ -z ${RUNAGFILE_MENU:+x} ]; then
    softfail "Menu is empty"
    return $?
  fi
  menu::select_and_run "${RUNAGFILE_MENU[@]}"
  softfail_unless_good_code $?
}

runagfile_menu::present() {
  test -n "${RUNAGFILE_MENU:+x}"
}

runagfile_menu::clear() {
  RUNAGFILE_MENU=()
}

runagfile_menu::display_for() {(
  runagfile_menu::clear || softfail || return $?
  "$@" || softfail || return $?
  runagfile_menu::display
  softfail_unless_good "Error performing runagfile_menu::display ($?)" $?
)}

runagfile_menu::add_defaults() {
  runagfile_menu::add_header "Same menu with certain flags set" || softfail || return $?

  runagfile_menu::add task::with_update_secrets runagfile_menu::display || softfail || return $?
  runagfile_menu::add task::with_verbose_task runagfile_menu::display || softfail || return $?

  if [ -d "${HOME}/.runag" ]; then
    runagfile_menu::add_header "Rùnag and rùnagfiles" || softfail || return $?
    
    runagfile_menu::add runag::create_or_update_offline_install || softfail || return $?
    runagfile_menu::add runag::update || softfail || return $?
  fi
}
