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

log::elapsed-time() {
  echo "Elapsed time: $((SECONDS / 3600))h$(((SECONDS % 3600) / 60))m$((SECONDS % 60))s"
}

log::success() {
  local message="$1"
  log::with-color "${message}" 10
}

log::notice() {
  local message="$1"
  log::with-color "${message}" 11
}

log::error() {
  local message="$1"
  log::with-color "${message}" 1 >&2
}

log::with-color() {
  local message="$1"
  local foregroundColor="$2"
  local backgroundColor="${3:-}"

  local foregroundColorSeq="" backgroundColorSeq="" defaultColorSeq=""

  if terminal::have-16-colors; then
    foregroundColorSeq="$(tput setaf "${foregroundColor}")" || echo "Sopka: Unable to get terminal sequence from tput ($?)" >&2

    if [ -n "${backgroundColor:-}" ]; then
      backgroundColorSeq="$(tput setab "${backgroundColor}")" || echo "Sopka: Unable to get terminal sequence from tput ($?)" >&2
    fi
    
    defaultColorSeq="$(tput sgr 0)" || echo "Sopka: Unable to get terminal sequence from tput ($?)" >&2
  fi

  echo "${foregroundColorSeq}${backgroundColorSeq}${message}${defaultColorSeq}"
}
