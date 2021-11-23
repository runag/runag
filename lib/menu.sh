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
  local commandsList=()

  if ! [ -t 0 ] || ! [ -t 1 ]; then
    softfail "Menu was called while not in terminal"
    return $?
  fi

  local colorA; colorA="$(terminal::color 13)" || softfail || return $?
  local colorB; colorB="$(terminal::color 15)" || softfail || return $?
  local headerColor; headerColor="$(terminal::color 14)" || softfail || return $?
  local defaultColor; defaultColor="$(terminal::default-color)" || softfail || return $?

  local index=1 item currentColor=""
  echo ""

  for item in "$@"; do
    if [ -z "${item}" ]; then
      echo ""
      currentColor=""

    elif [[ "${item}" =~ ^\# ]]; then
      echo "  ${headerColor}== ${item:1} ==${defaultColor}"
      currentColor=""

    else
      if [ "${currentColor}" = "${colorA}" ]; then
        currentColor="${colorB}"
      else
        currentColor="${colorA}"
      fi

      echo "  ${currentColor}$((index))) ${item}${defaultColor}"
      
      ((index+=1))
      commandsList+=("${item}")

    fi
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
      softfail "Read failed (${readStatus})"
      return $?
    fi
  fi

  if ! [[ "${inputText}" =~ ^[0-9]+$ ]]; then
    softfail "Please select number"
    return $?
  fi

  if [ -z "${commandsList[$((inputText-1))]:+x}" ]; then
    softfail "Selected number is not in the list"
    return $?
  fi

  local selectedItem="${commandsList[$((inputText-1))]}"

  # I use "test" instead of "|| fail" here in case if someone wants
  # to use "set -o errexit" in their functions

  eval "${selectedItem}"
  softfail-unless-good "Error performing ${selectedItem}" $? || return $?

  log::success "Done: ${selectedItem}"
  return 0
}
