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

# I use "test $? = 0" instead of "|| fail" for the case if someone wants to "set -o errexit" in their functions

# Select-based implementation
menu::builtin-select-and-run() {
  test -t 0 || fail "Menu was called with the STDIN which is not a terminal"
  local action
  select action in "$@"; do 
    test -n "${action}" || fail "Please select something"
    ${action} # I use "test" instead of "|| fail" here for the case if someone wants to "set -o errexit" in their functions
    test $? = 0 || fail "Error performing ${action}"
    break
  done
}

menu::select-and-run() {
  menu::select-argument-and-run menu::just-run "$@"
  test $? = 0 || fail "Error performing $@"
}

menu::select-argument-and-run() {
  local list=("${@:2}")

  if ! [ -t 0 ]; then
    fail "Menu was called while not in terminal"
  fi

  echo "Please select:"
  echo ""
  local index item nextItem group nextGroup lastGroup="" lastGroupIsBig=false
  for index in "${!list[@]}"; do
    item="${list[${index}]}"
    nextItem="${list[$((index+1))]:-}"

    group="$(echo "${item}" | sed 's/^\([^:]*\).*/\1/')" || fail
    nextGroup="$(echo "${nextItem}" | sed 's/^\([^:]*\).*/\1/')" || fail

    if [ "${lastGroup}" = "${group}" ]; then
      lastGroupIsBig=true
    else    
      if [ "${lastGroup}" != "" ]; then
        if [ "${lastGroupIsBig}" = true ] || [ "${nextGroup}" = "${group}" ]; then
          echo ""
        fi
      fi
      lastGroup="${group}"
      lastGroupIsBig=false
    fi

    echo "  $((index+1))) ${item}"
  done
  echo ""
  echo -n "${PS3:-"#? "}"

  local inputText readStatus
  IFS="" read -r inputText
  readStatus=$?

  if [ ${readStatus} != 0 ]; then
    if [ ${readStatus} = 1 ] && [ -z "${inputText}" ]; then
      exit 0
    else
      fail "Read failed (${readStatus})"
    fi
  fi

  if ! [[ "${inputText}" =~ ^[0-9]+$ ]]; then
    fail "Please select number"
  fi

  local selectedItem="${list[$((inputText-1))]}" || fail

  $1 ${selectedItem}
  test $? = 0 || fail "Error performing $1 ${selectedItem}"
}

menu::just-run() {
  "$@"
  test $? = 0 || fail "Error performing $@"
}
