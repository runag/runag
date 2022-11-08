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

offline_sopka_install::create_or_update() {
  local sopka_path="${HOME}"/.sopka

  if [ ! -d "${sopka_path}/.git" ]; then
    softfail "Unable to find sopka checkout" || return $?
  fi

  local sopka_remote_url; sopka_remote_url="$(git -C "${sopka_path}" remote get-url origin)" || softfail || return $?

  git::create_or_update_mirror "${sopka_remote_url}" sopka.git || softfail || return $?

  dir::make_if_not_exists "sopkafiles" || softfail || return $?

  local sopkafile_path; for sopkafile_path in "${sopka_path}/sopkafiles"/*; do
    if [ -d "${sopkafile_path}" ]; then
      local sopkafile_dir_name; sopkafile_dir_name="$(basename "${sopkafile_path}")" || softfail || return $?
      local sopkafile_remote_url; sopkafile_remote_url="$(git -C "${sopkafile_path}" remote get-url origin)" || softfail || return $?

      git::create_or_update_mirror "${sopkafile_remote_url}" "sopkafiles/${sopkafile_dir_name}" || softfail || return $?
    fi
  done

  if [ ! -f deploy-offline.sh ] && [ ! -f deploy-offline.sh.asc ]; then
    cp "${sopka_path}/src/deploy-offline.sh" . || softfail || return $?
    cp "${sopka_path}/src/deploy-offline.sh.asc" . || softfail || return $?
  fi
}
