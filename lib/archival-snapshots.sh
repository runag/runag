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

# :? here is to make sure we don't accidentally cleanup root directory or some other unexpected location

archival_snapshots::create() {
  local source="${1:?}"
  local dest="${2:?}"
  local snapshot_name="${3:-}"

  local current_date; current_date="$(date --utc "+%Y%m%dT%H%M%SZ")" || softfail || return $?

  btrfs subvolume snapshot -r "${source}" "${dest}/${current_date}${snapshot_name:+"-${snapshot_name}"}" || softfail || return $?
}

archival_snapshots::cleanup() {
  local snapshots_dir="${1:?}" 
  local keep_amount="${2:-10}"

  local snapshot_path
  local remove_this_snapshot

  if [ ! -f "${snapshots_dir:?}"/.this-is-archival-snapshots-directory ]; then
    softfail "Unable to find archival snapshots directory flag. To indicate that it is safe to perform automatic cleanup please put \".this-is-archival-snapshots-directory\" file to the directory that you sure it is safe to cleanup."
    return $? # the expression takes a line of its own, because if softfail fails to set non-zero exit status, then we still need to make sure a return from the function will happen here
  fi

  for snapshot_path in "${snapshots_dir:?}"/*; do # :?}" here is to make sure we don't accidentally cleanup root directory
    if [ -d "${snapshot_path:?}" ]; then
      echo "${snapshot_path:?}"
    fi
  done | sort | head "--lines=-${keep_amount:?}" | \
  while IFS="" read -r remove_this_snapshot; do
    # :?}" down here is for no reason?
    echo "Removing ${remove_this_snapshot:?}..."

    if [ "$(stat --format=%i "${remove_this_snapshot:?}")" -eq 256 ]; then
      sudo btrfs subvolume delete "${remove_this_snapshot:?}" || softfail || return $?
    else
      rm -rf "${remove_this_snapshot:?}" || softfail || return $? # TODO: is it good idea to use rm here? maybe create another function or add --allow-rm flag?
    fi
  done

  if [[ "${PIPESTATUS[*]}" =~ [^0[:space:]] ]]; then
    softfail || return $?
  fi
}
