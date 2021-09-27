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
  export SOPKA_UPDATE_SECRETS=true
  "$@"
  test $? = 0 || fail "Error performing ${1:-"(argument is empty)"}"
}

sopka::update() {
  if [ -d "${HOME}/.sopka/.git" ]; then
    git -C "${HOME}/.sopka" pull || fail

    local fileFolder
    for fileFolder in "${HOME}"/.sopka/sopkafiles/*; do
      if [ -d "${fileFolder}/.git" ]; then
        git -C "${fileFolder}" pull || fail
      fi
    done
  fi
}

sopka::add() {
  local packageId="$1"
  local dest; dest="$(echo "${packageId}" | tr "/" "-")" || fail
  git::place-up-to-date-clone "https://github.com/${packageId}.git" "${HOME}/.sopka/sopkafiles/github-${dest}" || fail
}

sopka-menu::add() {
  if [ -z ${SOPKA_MENU+x} ]; then
    SOPKA_MENU=()
  fi
  SOPKA_MENU+=("$@")
}

sopka-menu::display() {
  if [ -z ${SOPKA_MENU+x} ]; then
    fail "Menu is empty"
  fi
  menu::select-and-run "${SOPKA_MENU[@]}"
  test $? = 0 || fail "Error performing menu::select-and-run"
}

sopka-menu::is-present() {
  test -n "${SOPKA_MENU+x}"
}

sopka-menu::clear() {
  SOPKA_MENU=()
}

sopka::print-license() {
  cat <<EOT
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
EOT
}
