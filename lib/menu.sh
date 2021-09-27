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

menu::select-and-run() {
  menu::select-argument-and-run menu::just-run "$@"
  test $? = 0 || fail "Error performing ${1:-"(argument is empty)"}"
}

menu::select-argument-and-run() {
  local list=("${@:2}")

  if ! [ -t 0 ]; then
    fail "Menu was called while not in terminal"
  fi

  local colorA="" colorB="" normalColor=""

  if [ -t 1 ]; then
    local colorsAmount; colorsAmount="$(tput colors 2>/dev/null)"

    # shellcheck disable=SC2181
    if [ $? = 0 ] && [ "${colorsAmount}" -ge 16 ]; then
      colorA="$(tput setaf 14)"
      colorB="$(tput setaf 15)"
      normalColor="$(tput sgr 0)"
    fi
  fi

  echo ""
  local index item nextItem group nextGroup lastGroup="" lastGroupIsBig=false currentColor=""
  for index in "${!list[@]}"; do
    item="${list[${index}]}"
    nextItem="${list[$((index+1))]:-}"

    group="$(echo "${item}" | sed 's/ .*$//' | sed 's/::[^:]*$//'; test "${PIPESTATUS[*]}" = "0 0 0")" || fail
    nextGroup="$(echo "${nextItem}" | sed 's/ .*$//' | sed 's/::[^:]*$//'; test "${PIPESTATUS[*]}" = "0 0 0")" || fail

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

    if [ "${currentColor}" = "${colorA}" ]; then
      currentColor="${colorB}"
    else
      currentColor="${colorA}"
    fi

    echo "  ${currentColor}$((index+1))) ${item}${normalColor}"
  done

  echo ""
  echo -n "${PS3:-"Please select number: "}"

  local inputText readStatus
  IFS="" read -r inputText
  readStatus=$?

  if [ ${readStatus} != 0 ]; then
    if [ ${readStatus} = 1 ] && [ -z "${inputText}" ]; then
      echo "cancelled" >&2
      exit 0
    else
      fail "Read failed (${readStatus})"
    fi
  fi

  if ! [[ "${inputText}" =~ ^[0-9]+$ ]]; then
    fail "Please select number"
  fi

  local selectedItem="${list[$((inputText-1))]}" || fail

  # shellcheck disable=SC2086
  $1 ${selectedItem}
  test $? = 0 || fail "Error performing $1 ${selectedItem}"
}

menu::just-run() {
  "$@"
  test $? = 0 || fail "Error performing ${1:-"(argument is empty)"}"
}
