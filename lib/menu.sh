#!/usr/bin/env bash

#  Copyright 2012-2019 Stanislav Senotrusov <stan@senotrusov.com>
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

  echo "Please select:"
  local i
  for i in "${!list[@]}"; do
    echo "  ${i}: ${list[$i]}"
  done
  echo -n "> "

  local action
  IFS="" read -r action || fail

  if [ -n "${action:-}" ]; then
    local actionFunction="${list[$action]}"
    declare -f "${actionFunction}" >/dev/null || fail "Argument must be a function name"
    "${actionFunction}" || fail
  fi
}
