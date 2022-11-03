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

sopka_menu::add() {
  if [ -z ${SOPKA_MENU:+x} ]; then
    SOPKA_MENU=()
  fi

  local command_string; printf -v command_string " %q" "$@" || softfail "Unable to produce command string" || return $?
  SOPKA_MENU+=("${command_string:1}")
}

sopka_menu::add_raw() {
  if [ -z ${SOPKA_MENU:+x} ]; then
    SOPKA_MENU=()
  fi

  SOPKA_MENU+=("$1")
}

sopka_menu::add_delimiter() {
  if [ -z ${SOPKA_MENU:+x} ]; then
    SOPKA_MENU=()
  fi
  SOPKA_MENU+=("")
}

sopka_menu::add_header() {
  if [ -z ${SOPKA_MENU:+x} ]; then
    SOPKA_MENU=()
  fi
  SOPKA_MENU+=("#$1")
}

sopka_menu::add_subheader() {
  if [ -z ${SOPKA_MENU:+x} ]; then
    SOPKA_MENU=()
  fi
  SOPKA_MENU+=("##$1")
}

sopka_menu::add_note() {
  if [ -z ${SOPKA_MENU:+x} ]; then
    SOPKA_MENU=()
  fi
  SOPKA_MENU+=("#/$1")
}

sopka_menu::display() {
  if [ -z ${SOPKA_MENU:+x} ]; then
    softfail "Menu is empty"
    return $?
  fi
  menu::select_and_run "${SOPKA_MENU[@]}"
  softfail_unless_good_code $?
}

sopka_menu::is_present() {
  test -n "${SOPKA_MENU:+x}"
}

sopka_menu::clear() {
  SOPKA_MENU=()
}

sopka_menu::add_defaults() {
  sopka_menu::add_header "Same menu with certain flags set" || softfail || return $?

  sopka_menu::add task::with_update_secrets sopka_menu::display || softfail || return $?
  sopka_menu::add task::with_verbose_task sopka_menu::display || softfail || return $?

  if [ -d "${HOME}/.sopka" ]; then
    sopka_menu::add_header "Sopka and sopkafiles" || softfail || return $?
    
    sopka_menu::add sopka::update || softfail || return $?
    sopka_menu::add sopka::make_local_copy || softfail || return $?
  fi
}
