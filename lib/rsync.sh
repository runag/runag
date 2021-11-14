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

rsync::sync-to-remote() {
  rsync::sync "$1" "${REMOTE_HOST:-}:$2" || softfail || return $?
}

rsync::sync-from-remote() {
  rsync::sync "${REMOTE_HOST:-}:$1" "$2" || softfail || return $?
}

rsync::set-args() {
  if [ "${SOPKA_RSYNC_DELETE_AND_BACKUP:-}" = "true" ]; then
    local timestamp; timestamp="$(date --utc +"%Y%m%dT%H%M%SZ")" || softfail || return $?

    rsyncArgs+=("--delete")
    rsyncArgs+=("--backup")
    rsyncArgs+=("--backup-dir=.sopka-rsync-backups/${timestamp}")
    rsyncArgs+=("--filter=protect_.sopka-rsync-backups")
  fi

  if [ "${SOPKA_RSYNC_WITHOUT_CHECKSUMS:-}" != "true" ]; then
    rsyncArgs+=("--checksum")
  fi

  if declare -p SOPKA_RSYNC_ARGS >/dev/null 2>&1; then
    rsyncArgs=("${rsyncArgs[@]}" "${SOPKA_RSYNC_ARGS[@]}")
  fi
}

rsync::sync() {
  local rsyncArgs=()

  rsync::set-args || softfail || return $?

  rsync::run \
    --links \
    --perms \
    --recursive \
    --times \
    "${rsyncArgs[@]}" \
    "$@" || softfail || return $?
}

rsync::run() {
  ssh::make-user-config-dir-if-not-exists || softfail || return $?

  local sshArgs=()
  ssh::set-args || softfail || return $?

  local sshArgsString
  printf -v sshArgsString " '%s'" "${sshArgs[@]}" || softfail || return $?

  rsync --rsh "ssh ${sshArgsString:1}" "$@" || softfail || return $?
}

# REMOTE_HOST=example.com sopka rsync::upload ~/.sopka/ .sopka
