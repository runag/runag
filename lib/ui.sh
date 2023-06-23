#!/usr/bin/env bash

#  Copyright 2012-2022 Rùnag project contributors
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

ui::confirm() {
  if [ -n "${1:-}" ]; then
    log::warning "$1" || fail
  fi

  local user_input; IFS="" read -r user_input || fail

  while [ "${user_input}" != yes ]; do
    if [ "${user_input}" = no ]; then
      return 1
    fi

    log::warning 'Please enter "yes" or "no" to continue' || fail
    
    IFS="" read -r user_input || fail
  done

  return 0
}
