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

rsync::upload() {
  rsync::transfer "$1" "${REMOTE_HOST:-}:$2" || fail
}

rsync::download() {
  rsync::transfer "${REMOTE_HOST:-}:$1" "$2" || fail
}

rsync::transfer() {
  rsync::remote \
    --checksum \
    --compress \
    --delete \
    --links \
    --perms \
    --recursive \
    --times \
    --whole-file \
    "$@" || fail
}

rsync::remote() {
  local rshOption

  if [ ! -d "${HOME}/.ssh" ]; then
    mkdir -p -m 0700 "${HOME}/.ssh" || fail
  fi

  rshOption="ssh \
    -o ControlMaster=auto \
    -o ControlPath=$(printf "%q" "$HOME/.ssh/%C.control-socket") \
    -o ControlPersist=yes \
    -o ServerAliveInterval=25 \
    ${REMOTE_PORT:+-p} ${REMOTE_PORT:+"${REMOTE_PORT}"} \
    ${REMOTE_USER:+-l} ${REMOTE_USER:+"${REMOTE_USER}"}" || fail

  rsync \
    --rsh "$rshOption" \
    "$@" || fail
}
