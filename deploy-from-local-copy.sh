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

if [ "${SOPKA_VERBOSE:-}" = true ]; then
    set -o xtrace;
fi

set -o nounset

fail() {
  echo "${1:-"General failure"}"
  exit "${2:-1}"
}

if ! command -v git > /dev/null; then
  sudo DEBIAN_FRONTEND=noninteractive apt-get update || fail
  sudo DEBIAN_FRONTEND=noninteractive apt-get -y install git || fail
fi

reset_permissions() {
  if [ -n "$(git status --porcelain)" ]; then
    git diff --no-ext-diff --patch -R | grep -E "^(diff|(old|new) mode)" | git apply
    [[ "${PIPESTATUS[*]}" =~ ^0\ [01]\ 0$ ]] || fail "Unable to reset permissions"
  fi
}

deploy_local_copy() {(
  local dest_dir="$1"
  
  local unresolved_source_dir; unresolved_source_dir="$(dirname "${BASH_SOURCE[0]}")" || fail
  local source_dir; source_dir="$(cd "${unresolved_source_dir}" >/dev/null 2>&1 && pwd)" || fail

  test -d "${dest_dir}" && fail "Already exists: ${dest_dir}"

  cp -R "${source_dir}" "${dest_dir}" || fail
  
  cd "${dest_dir}" || fail
  configure_repo "${source_dir}" || fail

  local sopkafile_path; for sopkafile_path in sopkafiles/*; do
    if [ -d "${sopkafile_path}" ]; then
      (
        cd "${sopkafile_path}" || fail
        configure_repo "${source_dir}/${sopkafile_path}" || fail
      ) || fail
    fi
  done
)}

configure_repo() {
  git config core.fileMode true || fail
  reset_permissions || fail
  git remote add local-copy "$1" || fail
}

deploy_local_copy "${HOME}/.sopka" || fail

"${HOME}/.sopka/bin/sopka"
