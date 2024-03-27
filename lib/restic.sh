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

# restic::install "0.14.0"

restic::install() {
  local restic_version="$1"

  if command -v restic >/dev/null; then
    local installed_restic_version; installed_restic_version="$(restic version)" || softfail || return $?
    if [[ "${installed_restic_version}" =~ ^[^[:digit:]]+([[:digit:]\.]+) ]] && [ "${BASH_REMATCH[1]}" = "${restic_version}" ]; then
      return 0
    fi
  fi

  local temp_file; temp_file="$(mktemp)" || softfail || return $?

  curl \
    --location \
    --fail \
    --silent \
    --show-error \
    --output "${temp_file}" \
    "https://github.com/restic/restic/releases/download/v${restic_version}/restic_${restic_version}_linux_amd64.bz2" >/dev/null || softfail || return $?

  bzip2 --decompress --stdout "${temp_file}" >"${temp_file}.out" || softfail || return $?

  file::write --sudo --mode 0755 --absorb "${temp_file}.out" /usr/local/bin/restic || softfail || return $?

  rm "${temp_file}" || softfail || return $?
}

restic::open_mount_when_available() {
  local mount_path="$1"

  local cutoff_time="$((SECONDS+40))"

  (
    while [ ! -d "${mount_path}/snapshots" ]; do
      sleep 0.1 || fail
      if [ "${SECONDS}" -gt "${cutoff_time}" ]; then
        fail "Maximum time to wait for mount to complete has been reached"
      fi
    done
    
    if [ -d "${mount_path}/snapshots/latest" ]; then
      xdg-open "${mount_path}/snapshots/latest" || fail
    else
      xdg-open "${mount_path}" || fail
    fi
  ) &
}

restic::is_repository_not_exists() {
  restic cat config 2>&1 | grep -qFx "Is there a repository at the following location?"

  local saved_pipe_status=("${PIPESTATUS[@]}")

  if [ "${saved_pipe_status[0]}" != 0 ] && [ "${saved_pipe_status[1]}" = 0 ]; then
    return 0
  fi

  return 1
}
