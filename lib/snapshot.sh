#!/usr/bin/env bash

#  Copyright 2012-2025 Runag project contributors
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

# snapshot::init --monthly .
#
snapshot::init() {
  local daily_snapshot=false
  local weekly_snapshot=false
  local monthly_snapshot=false
  local snapshots_by_name=false
  local snapshots_by_time=false

  if [ "$#" = 1 ]; then
    snapshots_by_time=true
  fi

  while [ "$#" -gt 0 ]; do
    case "$1" in
      -d|--daily)
        daily_snapshot=true
        shift
        ;;
      -w|--weekly)
        weekly_snapshot=true
        shift
        ;;
      -m|--monthly)
        monthly_snapshot=true
        shift
        ;;
      -n|--name)
        snapshots_by_name=true
        shift
        ;;
      -t|--time)
        snapshots_by_time=true
        shift
        ;;
      -*)
        softfail "Unknown argument: $1" || return $?
        ;;
      *)
        break
        ;;
    esac
  done

  if [ "$#" != 1 ]; then
    softfail "Snapshots directory must be specified"
    return $?
  else
    local dest="${1:?}"
  fi

  dir::ensure_exists --mode 0700 "${dest}" || softfail || return $?

  local snapshots_path
  
  if [ "${daily_snapshot}" = true ]; then
    snapshots_path="${dest}/daily-snapshots"

    dir::ensure_exists --mode 0700 "${snapshots_path}" || softfail || return $?
    touch "${snapshots_path}/.safe-to-cleanup" || softfail || return $?
  fi

  if [ "${weekly_snapshot}" = true ]; then
    snapshots_path="${dest}/weekly-snapshots"

    dir::ensure_exists --mode 0700 "${snapshots_path}" || softfail || return $?
    touch "${snapshots_path}/.safe-to-cleanup" || softfail || return $?
  fi

  if [ "${monthly_snapshot}" = true ]; then
    snapshots_path="${dest}/monthly-snapshots"

    dir::ensure_exists --mode 0700 "${snapshots_path}" || softfail || return $?
    touch "${snapshots_path}/.safe-to-cleanup" || softfail || return $?
  fi

  if [ "${snapshots_by_name}" = true ]; then
    snapshots_path="${dest}/snapshots-by-name"

    dir::ensure_exists --mode 0700 "${snapshots_path}" || softfail || return $?
    touch "${snapshots_path}/.safe-to-cleanup" || softfail || return $?
  fi

  if [ "${snapshots_by_time}" = true ]; then
    snapshots_path="${dest}/snapshots-by-time"

    dir::ensure_exists --mode 0700 "${snapshots_path}" || softfail || return $?
    touch "${snapshots_path}/.safe-to-cleanup" || softfail || return $?
  fi
}

snapshot::create() {
  local daily_snapshot=false
  local weekly_snapshot=false
  local monthly_snapshot=false
  local snapshots_by_name=false
  local snapshots_by_time=false

  local snapshot_name

  if [ "$#" = 2 ]; then
    snapshots_by_time=true
  fi

  while [ "$#" -gt 0 ]; do
    case "$1" in
      -d|--daily)
        daily_snapshot=true
        shift
        ;;
      -w|--weekly)
        weekly_snapshot=true
        shift
        ;;
      -m|--monthly)
        monthly_snapshot=true
        shift
        ;;
      -n|--name)
        snapshots_by_name=true
        snapshot_name="${2:?}"
        shift; shift
        ;;
      -t|--time)
        snapshots_by_time=true
        shift
        ;;
      -*)
        softfail "Unknown argument: $1" || return $?
        ;;
      *)
        break
        ;;
    esac
  done

  if [ "$#" != 2 ]; then
    softfail "Source and snapshot directories must be specified"
    return $?
  else
    local source="${1:?}"
    local dest="${2:?}"
  fi

  local snapshot_path

  if [ "${daily_snapshot}" = true ]; then
    snapshot_path="${dest}/daily-snapshots/$(date --utc "+%Y-%m-%d")" || softfail || return $?
    if [ ! -d "${snapshot_path}" ]; then
      btrfs subvolume snapshot -r "${source}" "${snapshot_path}" || softfail || return $?
    fi
  fi

  if [ "${weekly_snapshot}" = true ]; then
    snapshot_path="${dest}/weekly-snapshots/$(date --utc "+%G-W%V")" || softfail || return $?
    if [ ! -d "${snapshot_path}" ]; then
      btrfs subvolume snapshot -r "${source}" "${snapshot_path}" || softfail || return $?
    fi
  fi

  if [ "${monthly_snapshot}" = true ]; then
    snapshot_path="${dest}/monthly-snapshots/$(date --utc "+%Y-%m")" || softfail || return $?
    if [ ! -d "${snapshot_path}" ]; then
      btrfs subvolume snapshot -r "${source}" "${snapshot_path}" || softfail || return $?
    fi
  fi

  if [ "${snapshots_by_name}" = true ]; then
    snapshot_path="${dest}/snapshots-by-name/${snapshot_name}"
    if [ ! -d "${snapshot_path}" ]; then
      btrfs subvolume snapshot -r "${source}" "${snapshot_path}" || softfail || return $?
    else
      softfail "Snapshot directory already exist: ${snapshot_path}"
      return $?
    fi
  fi

  if [ "${snapshots_by_time}" = true ]; then
    snapshot_path="${dest}/snapshots-by-time/$(date --utc "+%Y-%m-%dT%H%M%SZ")" || softfail || return $?
    if [ ! -d "${snapshot_path}" ]; then
      btrfs subvolume snapshot -r "${source}" "${snapshot_path}" || softfail || return $?
    else
      softfail "Snapshot directory already exist: ${snapshot_path}"
      return $?
    fi
  fi
}

snapshot::cleanup() {
  local daily_snapshot=false
  local weekly_snapshot=false
  local monthly_snapshot=false
  local snapshots_by_time=false

  local daily_snapshot_count=30
  local weekly_snapshot_count=14
  local monthly_snapshot_count=12
  local snapshots_by_time_count=14

  if [ "$#" = 1 ]; then
    snapshots_by_time=true
  fi

  while [ "$#" -gt 0 ]; do
    case "$1" in
      -d|--daily)
        daily_snapshot=true
        if [[ "${2:-}" =~ ^[[:digit:]]+$ ]]; then
          daily_snapshot_count="$2"
          shift
        fi
        shift
        ;;
      -w|--weekly)
        weekly_snapshot=true
        if [[ "${2:-}" =~ ^[[:digit:]]+$ ]]; then
          weekly_snapshot_count="$2"
          shift
        fi
        shift
        ;;
      -m|--monthly)
        monthly_snapshot=true
        if [[ "${2:-}" =~ ^[[:digit:]]+$ ]]; then
          monthly_snapshot_count="$2"
          shift
        fi
        shift
        ;;
      -t|--time)
        snapshots_by_time=true
        if [[ "${2:-}" =~ ^[[:digit:]]+$ ]]; then
          snapshots_by_time_count="$2"
          shift
        fi
        shift
        ;;
      -*)
        softfail "Unknown argument: $1" || return $?
        ;;
      *)
        break
        ;;
    esac
  done

  if [ "$#" != 1 ]; then
    softfail "Snapshots directory must be specified"
    return $?
  else
    local dest="${1:?}"
  fi

  if [ "${daily_snapshot}" = true ]; then
    snapshot::cleanup::dir "${dest}/daily-snapshots" "${daily_snapshot_count}"
  fi

  if [ "${weekly_snapshot}" = true ]; then
    snapshot::cleanup::dir "${dest}/weekly-snapshots" "${weekly_snapshot_count}"
  fi

  if [ "${monthly_snapshot}" = true ]; then
    snapshot::cleanup::dir "${dest}/monthly-snapshots" "${monthly_snapshot_count}"
  fi

  if [ "${snapshots_by_time}" = true ]; then
    snapshot::cleanup::dir "${dest}/snapshots-by-time" "${snapshots_by_time_count}"
  fi
}

snapshot::cleanup::dir() {
  # use of :? in this function is to ensure we don't accidentally cleanup root directory
  # or some other unexpected location

  local snapshots_dir="${1:?}" 
  local keep_amount="${2:-10}"

  local snapshot_path
  local remove_this_snapshot

  if [ ! -f "${snapshots_dir:?}"/.safe-to-cleanup ]; then
    softfail "Unable to find safe to cleanup flag. To indicate that it is safe to perform automatic cleanup please put \".safe-to-cleanup\" file in the directory that you are sure it is safe to cleanup."
    # the return expression takes a line of its own, because if softfail fails to set non-zero exit status,
    # then we still need to make sure a return from the function will happen here
    return $? 
  fi

  # :?}" here is to make sure we don't accidentally cleanup root directory
  for snapshot_path in "${snapshots_dir:?}"/*; do
    if [ -d "${snapshot_path:?}" ]; then
      echo "${snapshot_path:?}"
    fi
  done | sort | head "--lines=-${keep_amount:?}" | \
  while IFS="" read -r remove_this_snapshot; do
    echo "Removing ${remove_this_snapshot:?}..."

    if [ "$(stat --format=%i "${remove_this_snapshot:?}")" -eq 256 ]; then
      sudo btrfs subvolume delete "${remove_this_snapshot:?}" || softfail || return $?
    else
      # TODO: is it good idea to use rm here? maybe create another function or add --allow-rm flag?
      rm -rf "${remove_this_snapshot:?}" || softfail || return $?
    fi
  done

  if [[ "${PIPESTATUS[*]}" =~ [^0[:space:]] ]]; then
    softfail || return $?
  fi
}
