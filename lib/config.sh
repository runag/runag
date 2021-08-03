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

config::install() {
  src="$1"
  dst="$2"

  if [ -f "${dst}" ]; then
    config::merge "${src}" "${dst}" || fail
  else
    local currentUserId; currentUserId="$(id -u)" || fail
    local currentGroupId; currentGroupId="$(id -g)" || fail

    local dirName; dirName="$(dirname "${dst}")" || fail "Unable to get dirName of '${dst}' ($?)"

    mkdir -p "${dirName}" || fail "Unable to mkdir -p '${dirName}' ($?)"

    cp "${src}" "${dst}" || fail "Unable to copy config from '${src}' to '${dst}' ($?)"

    chmod 0644 "${dst}" || fail "Unable to chmod '${dst}' ($?)"

    chown "${currentUserId}:${currentGroupId}" "${dst}" || fail "Unable to chown ${currentUserId}:${currentGroupId} ${dst} ($?)"
  fi
}

config::merge() {
  src="$1"
  dst="$2"

  # TODO: is mtime-based update possible here?

  if [ -t 0 ]; then
    if [ -f "${dst}" ]; then
      if ! diff --strip-trailing-cr "${src}" "${dst}" >/dev/null 2>&1; then

        if command -v git >/dev/null; then
          git diff --ignore-cr-at-eol --color --unified=6 --no-index "${dst}" "${src}" | tee
        else
          diff --strip-trailing-cr --context=6 --color "${dst}" "${src}"
        fi

        local action

        echo "Files are different:"
        echo "  ${src}"
        echo "  ${dst}"
        echo "Please choose an action to perform:"
        echo "  1: Use file from the repository to replace file on this machine"
        echo "  2: Use file from this machine to save it to the repository"
        echo "  3 (or Enter): Ignore conflict"

        IFS="" read -r action || fail

        if [ "${action}" = 1 ]; then
          cp "${src}" "${dst}" || fail
        elif [ "${action}" = 2 ]; then
          cp "${dst}" "${src}" || fail
        fi
      fi
    fi
  fi
}
