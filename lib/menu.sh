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

menu::select-and-run() {
  local list=("$@")

  if ! [ -t 0 ]; then
    fail "Menu was called while not in terminal"
  fi

  echo "Please select:"
  local i
  for i in "${!list[@]}"; do
    echo "  $((i+1)): ${list[$i]}"
  done
  echo -n "> "

  local action
  IFS="" read -r action || fail

  if ! [[ "${action}" =~ ^[0-9]+$ ]]; then
    fail "Please select number"
  fi

  local actionFunction="${list[$((action-1))]}" || fail

  # I use "test" instead of "|| fail" here for the case if someone wants to "set -o errexit" in their functions
  ${actionFunction}
  test $? = 0 || fail "Error performing ${actionFunction}"
}

menu::select-argument() {
  local list=("${@:2}")

  if ! [ -t 0 ]; then
    fail "Menu was called while not in terminal"
  fi

  echo "Please select:"
  local i
  for i in "${!list[@]}"; do
    echo "  $((i+1)): ${list[$i]}"
  done
  echo -n "> "

  local action
  IFS="" read -r action || fail

  if ! [[ "${action}" =~ ^[0-9]+$ ]]; then
    fail "Please select number"
  fi

  local selectedArgument="${list[$((action-1))]}" || fail

  # I use "test" instead of "|| fail" here for the case if someone wants to "set -o errexit" in their functions
  "$1" "${selectedArgument}"
  test $? = 0 || fail "Error performing $1 ${selectedArgument}"
}
