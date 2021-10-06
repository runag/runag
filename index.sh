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

sopka::load-lib() {
  # resolve symlink if needed
  if [ -L "${BASH_SOURCE[0]}" ]; then
    local indexPath; indexPath="$(readlink -f "${BASH_SOURCE[0]}")" || { echo "Sopka: Unable to readlink '${BASH_SOURCE[0]}' ($?)" >&2; return 1; }
  else
    local indexPath; indexPath="${BASH_SOURCE[0]}"
  fi

  # get dirname that yet may result to relative path
  local unresolvedSopkaDir; unresolvedSopkaDir="$(dirname "${indexPath}")" || { echo "Sopka: Unable to get a dirname of '${indexPath}' ($?)" >&2; return 1; }

  # get absolute path to dirname
  local sopkaDir; sopkaDir="$(cd "${unresolvedSopkaDir}" >/dev/null 2>&1 && pwd)" || { echo "Sopka: Unable to determine absolute path for '${unresolvedSopkaDir}' ($?)" >&2; return 1; }

  # set SOPKA_BIN_PATH if needed
  if [ -z "${SOPKA_BIN_PATH:-}" ] && [ -f "${sopkaDir}/bin/sopka" ] && [ -x "${sopkaDir}/bin/sopka" ]; then
    export SOPKA_BIN_PATH="${sopkaDir}/bin/sopka"
  fi

  # load all lib/*.sh
  local filePath; for filePath in "${sopkaDir}"/lib/*.sh; do
    if [ -f "${filePath}" ]; then
      . "${filePath}" || { echo "Sopka: Unable to load '${filePath}' ($?)" >&2; return 1; }
    fi
  done
}

sopka::load-lib || {
  echo "Sopka: Unable to perform sopka::load-lib' ($?)" >&2
  if [ "${BASH_SOURCE[0]}" != "$0" ]; then
    return 1 # use return if we are sourced
  else
    exit 1 # use exit if not
  fi
}
