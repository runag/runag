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

  if ! [ -t 0 ] || ! [ -t 1 ]; then
    softfail "Menu was called while not in terminal"
    return $?
  fi

  local colorA="" colorB="" defaultColor=""
  if [ -t 1 ]; then
    colorA="$(terminal::color 13)" || softfail || return $?
    colorB="$(terminal::color 15)" || softfail || return $?
    defaultColor="$(terminal::default-color)" || softfail || return $?
  fi

  echo ""
  local index item nextItem group nextGroup lastGroup="" lastGroupIsBig=false currentColor=""
  for index in "${!list[@]}"; do
    item="${list[${index}]}"
    nextItem="${list[$((index+1))]:-}"

    group="$(echo "${item}" | sed 's/ .*$//' | sed 's/::[^:]*$//'; test "${PIPESTATUS[*]}" = "0 0 0")" || softfail || return $?
    nextGroup="$(echo "${nextItem}" | sed 's/ .*$//' | sed 's/::[^:]*$//'; test "${PIPESTATUS[*]}" = "0 0 0")" || softfail || return $?

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

    echo "  ${currentColor}$((index+1))) ${item}${defaultColor}"
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

  if [ -z "${list[$((inputText-1))]:+x}" ]; then
    softfail "Selected number is not in the list"
    return $?
  fi

  local selectedItem="${list[$((inputText-1))]}"

  # I use "test" instead of "|| fail" here in case if someone wants
  # to use "set -o errexit" in their functions

  eval "${selectedItem}"
  softfail-unless-good "Error performing ${selectedItem}" $? || return $?

  if [ -t 1 ]; then
    log::success "Done: ${selectedItem}"
  fi

  return 0
}
