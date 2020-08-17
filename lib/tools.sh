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

sopka::nothing-deployed() {
  test -z "$(find . -maxdepth 1 -name '.sopka.*.deployed' -print -quit)"
}

tools::display-elapsed-time() {
  echo "Elapsed time: $((SECONDS / 3600))h$(((SECONDS % 3600) / 60))m$((SECONDS % 60))s"
}

tools::once-per-day() {
  local command="$1"
  local flagFile="${HOME}/.cache/sopka.once-per-day.${command}"
  local currentDate; currentDate="$(date +"%Y%m%d")" || fail

  mkdir -p "${HOME}/.cache" || fail

  if [ -f "${flagFile}" ]; then
    local savedDate; savedDate="$(cat "${flagFile}")" || fail
    if [ "${savedDate}" = "${currentDate}" ]; then
      return
    fi
  fi

  "${command}" || fail

  echo "${currentDate}" > "${flagFile}" || fail
}
