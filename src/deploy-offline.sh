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

set -o nounset

# shellcheck disable=2120
fail() {
  echo "${1:-"General failure"}" >&2
  exit "${2:-1}"
}

if ! command -v git >/dev/null; then
  sudo DEBIAN_FRONTEND=noninteractive apt-get update || fail
  sudo DEBIAN_FRONTEND=noninteractive apt-get -y install git || fail
fi

clone_local_mirror_perhaps() {
  local source_path="$1"
  local dest_path="$2"
  local remote_name="${3:-}"

  local source_path_full; source_path_full="$(cd "${source_path}" >/dev/null 2>&1 && pwd)" || fail

  if [ ! -d "${dest_path}" ]; then
    git clone "${source_path}" "${dest_path}" || fail

    local mirror_origin; mirror_origin="$(git -C "${source_path}" remote get-url origin)" || fail
    git -C "${dest_path}" remote set-url origin "${mirror_origin}" || fail

    if [ -n "${remote_name}" ]; then
      git -C "${dest_path}" remote add "${remote_name}" "${source_path_full}" || fail
    fi
  fi
}

if [ ! -d sopka.git ]; then
  fail "Unable to find sopka.git directory"
fi

install_path="${HOME}"/.sopka

clone_local_mirror_perhaps sopka.git "${install_path}" "offline-install" || fail

( if cd sopkafiles >/dev/null 2>&1; then
  for sopkafile in *; do
    if [ -d "${sopkafile}" ]; then
      clone_local_mirror_perhaps "${sopkafile}" "${install_path}/sopkafiles/${sopkafile}" "offline-install" || fail
    fi
  done
fi ) || fail

"${install_path}"/bin/sopka
