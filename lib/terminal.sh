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

terminal::have-16-colors(){
  local amount
  [ -t 1 ] && command -v tput >/dev/null && amount="$(tput colors 2>/dev/null)" && [ -n "${amount##*[!0-9]*}" ] && [ "${amount}" -ge 16 ]
}

terminal::print-color-table() {
  for i in {0..16..1}; do 
    echo "$(tput setaf "${i}")tput setaf ${i}$(tput sgr 0)"
  done
}
