#!/usr/bin/env bash

#  Copyright 2012-2020 Stanislav Senotrusov <stan@senotrusov.com>
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

rsync::determine-force-option() {
  if [ -z "${RSYNC_FORCE_OPTION:-}" ]; then
    rsync --help | grep --quiet "\-\-force\-delete"
    local savedPipeStatus="${PIPESTATUS[*]}"

    if [ "${savedPipeStatus}" = "0 0" ]; then
      RSYNC_FORCE_OPTION="--force-delete"
    elif [ "${savedPipeStatus}" = "0 1" ]; then
      RSYNC_FORCE_OPTION="--force"
    else
      fail "Unable to determine RSYNC_FORCE_OPTION"
    fi

    export RSYNC_FORCE_OPTION
  fi
}

rsync::upload() {
  rsync::remote "$1" "${REMOTE_HOST:-}:$2" || fail
}

rsync::remote() {
  if [ ! -d "${HOME}/.ssh" ]; then
    mkdir -p -m 0700 "${HOME}/.ssh" || fail
  fi

  rsync::determine-force-option || fail

  local rshOption="ssh \
    -o ControlMaster=auto \
    -o ControlPath=$(printf "%q" "$HOME/.ssh/%C.control-socket") \
    -o ControlPersist=yes \
    -o ServerAliveInterval=25 \
    ${REMOTE_PORT:+-p} ${REMOTE_PORT:+"${REMOTE_PORT}"} \
    ${REMOTE_USER:+-l} ${REMOTE_USER:+"${REMOTE_USER}"}"

  rsync \
    --archive \
    --checksum \
    --compress \
    --delete \
    --no-group \
    --no-owner \
    --rsh "$rshOption" \
    --safe-links \
    --whole-file \
    "$RSYNC_FORCE_OPTION" \
    "$1" "$2" || fail
}
