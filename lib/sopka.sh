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

sopka::with-update-secrets() {
  export UPDATE_SECRETS=true
  "$@"
  test $? = 0 || fail "Error performing $@"
}

sopka::update() {
  if [ -d "${HOME}/.sopka/.git" ]; then
    git -C "${HOME}/.sopka" pull || fail

    local fileFolder
    for fileFolder in "${HOME}"/.sopka/files/*; do
      if [ -d "${fileFolder}/.git" ]; then
        git -C "${fileFolder}" pull || fail
      fi
    done
  fi
}

sopka::add() {
  local packageName="$1"
  local dest; dest="$(echo "${packageName}" | tr "/" "-")" || fail
  git::place-up-to-date-clone "https://github.com/${packageName}.git" "${HOME}/.sopka/files/github-${dest}" || fail
}

sopka::add-menu-item() {
  if [ -z ${SOPKA_MENU+x} ]; then
    SOPKA_MENU=()
  fi
  SOPKA_MENU+=("$@")
}

sopka::display-menu() {
  if [ -z ${SOPKA_MENU+x} ]; then
    fail "Menu is empty"
  fi
  menu::select-and-run "${SOPKA_MENU[@]}"
  test $? = 0 || fail "Error performing menu::select-and-run"
}

sopka::is-menu-present() {
  test -n "${SOPKA_MENU+x}"
}

sopka::clear-menu() {
  SOPKA_MENU=()
}
