#!/usr/bin/env bash

#  Copyright 2012-2021 Stanislav Senotrusov <stan@senotrusov.com>
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

sopka-menu::add() {
  if [ -z ${SOPKA_MENU:+x} ]; then
    SOPKA_MENU=()
  fi
  SOPKA_MENU+=("$@")
}

sopka-menu::display() {
  if [ -z ${SOPKA_MENU:+x} ]; then
    softfail "Menu is empty"
    return $?
  fi
  menu::select-and-run "${SOPKA_MENU[@]}"
  softfail-unless-good-code $?
}

sopka-menu::is-present() {
  test -n "${SOPKA_MENU:+x}"
}

sopka-menu::clear() {
  SOPKA_MENU=()
}

sopka-menu::sort() {
  if [ -n "${SOPKA_MENU:+x}" ]; then
    local previousIFS="${IFS}"
    IFS=$'\n'
    # shellcheck disable=SC2207
    SOPKA_MENU=($(sort <<<"${SOPKA_MENU[*]}")) || { softfail; IFS="$previousIFS"; return 1; }
    IFS="$previousIFS"
  fi
}

sopka-menu::add-defaults() {
  if [[ "${OSTYPE}" =~ ^linux ]]; then
    sopka-menu::add sopka::linux::dangerously-set-hostname || softfail || return $?
    if linux::display-if-restart-required::is-available; then
      sopka-menu::add sopka::linux::display-if-restart-required || softfail || return $?
    fi
  fi

  if benchmark::is-available; then
    sopka-menu::add sopka::linux::run-benchmark || softfail || return $?
  fi

  if [ -d "${HOME}/.sopka" ]; then
    sopka-menu::add sopka::update || softfail || return $?
  fi

  sopka-menu::add "sopka::with-update-secrets sopka-menu::display" || softfail || return $?
  sopka-menu::add "sopka::with-verbose-tasks sopka-menu::display" || softfail || return $?
}
