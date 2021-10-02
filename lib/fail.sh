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

fail() {
  log::error "${1:-"Abnormal termination"}" || echo "Sopka: Unable to log error" >&2

  local i endAt=$((${#BASH_LINENO[@]}-1))
  for ((i=1; i<=endAt; i++)); do
    log::error "  ${BASH_SOURCE[${i}]}:${BASH_LINENO[$((i-1))]}: in \`${FUNCNAME[${i}]}'" || echo "Sopka: Unable to log error" >&2
  done

  exit "${2:-1}"
}
