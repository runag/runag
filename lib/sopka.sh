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

sopka::with-verbose-tasks() {
  export SOPKA_VERBOSE_TASKS=true
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

# Find and load sopkafile.
#
# Possible locations are:
#
# ./sopkafile
# ./sopkafile/index.sh
#
# ~/.sopkafile
# ~/.sopkafile/index.sh
#
# ~/.sopka/sopkafiles/*/index.sh
#
sopka::load-sopkafile() {
  if [ -f "./sopkafile" ]; then
    . "./sopkafile" || fail
  elif [ -f "./sopkafile/index.sh" ]; then
    . "./sopkafile/index.sh" || fail
  elif [ -n "${HOME:-}" ] && [ -f "${HOME:-}/.sopkafile" ]; then
    . "${HOME:-}/.sopkafile" || fail
  elif [ -n "${HOME:-}" ] && [ -f "${HOME:-}/.sopkafile/index.sh" ]; then
    . "${HOME:-}/.sopkafile/index.sh" || fail
  else
    local filePath fileFound=false
    for filePath in "${HOME}"/.sopka/sopkafiles/*/index.sh; do
      if [ -f "${filePath}" ]; then
        . "${filePath}" || fail
        fileFound=true
      fi
    done
    if [ "${fileFound}" = false ]; then
      fail "Unable to find sopkafile"
    fi
  fi
}

# I use "test" instead of "|| fail" here for the case if someone wants to "set -o errexit" in their functions
sopka::launch() {
  local statusCode
  if [ -n "${1:-}" ]; then
    declare -f "$1" >/dev/null || fail "Sopka: Argument must be a function name: $1"
    "$@"
    statusCode=$?
    test $statusCode = 0 || fail "Sopka: Error performing $1", $statusCode
  else
    if [ "${0:0:1}" != "-" ] && [ "$(basename "$0")" = "sopka" ]; then
      if declare -f sopkafile::main >/dev/null; then
        sopkafile::main
        statusCode=$?
        test $statusCode = 0 || fail "Sopka: Error performing sopkafile::main", $statusCode
      elif sopka-menu::is-present; then
        sopka-menu::display
        statusCode=$?
        test $statusCode = 0 || fail "Sopka: Error performing sopka-menu::display", $statusCode
      else
        fail "Sopka: Please specify a function name to run, define a sopkafile::main, or add items to a menu"
      fi
    fi
  fi
}
