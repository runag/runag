#!/usr/bin/env bash

#  Copyright 2012-2022 Stanislav Senotrusov <stan@senotrusov.com>
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

rsync::sync_to_remote() {
  rsync::sync "$1" "${REMOTE_HOST:-}:$2" || softfail || return $?
}

rsync::sync_from_remote() {
  rsync::sync "${REMOTE_HOST:-}:$1" "$2" || softfail || return $?
}

rsync::set_args() {
  if [ "${RUNAG_RSYNC_DELETE_AND_BACKUP:-}" = "true" ]; then
    local timestamp; timestamp="$(date --utc +"%Y%m%dT%H%M%SZ")" || softfail || return $?

    rsync_args+=("--delete")
    rsync_args+=("--backup")
    rsync_args+=("--backup-dir=.runag-rsync-backups/${timestamp}")
    rsync_args+=("--filter=protect_.runag-rsync-backups")
  fi

  if [ "${RUNAG_RSYNC_WITHOUT_CHECKSUMS:-}" != "true" ]; then
    rsync_args+=("--checksum")
  fi

  if declare -p RUNAG_RSYNC_ARGS >/dev/null 2>&1; then
    rsync_args=("${rsync_args[@]}" "${RUNAG_RSYNC_ARGS[@]}")
  fi
}

rsync::sync() {
  local rsync_args=()

  rsync::set_args || softfail || return $?

  rsync::run \
    --links \
    --perms \
    --recursive \
    --times \
    "${rsync_args[@]}" \
    "$@" || softfail || return $?
}

rsync::run() {
  local ssh_args=()
  ssh::set_args || softfail || return $?

  local ssh_args_string
  printf -v ssh_args_string " '%s'" "${ssh_args[@]}" || softfail || return $?

  rsync --rsh "ssh ${ssh_args_string:1}" "$@" || softfail || return $?
}

# REMOTE_HOST=example.com runag rsync::upload ~/.runag/ .runag
