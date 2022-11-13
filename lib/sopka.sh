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

sopka::print_license() {
  cat <<SHELL
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
SHELL
}

sopka::update() {
  if [ -d "${HOME}/.sopka/.git" ]; then
    git -C "${HOME}/.sopka" pull || softfail || return $?
  fi

  sopkafile::update-everything-in-sopka || softfail || return $?
}

sopka::create_or_update_offline_install() {
  local sopka_path="${HOME}"/.sopka

  if [ ! -d "${sopka_path}/.git" ]; then
    softfail "Unable to find sopka checkout" || return $?
  fi

  local current_directory; current_directory="$(pwd)" || softfail || return $?

  local sopka_remote_url; sopka_remote_url="$(git -C "${sopka_path}" remote get-url origin)" || softfail || return $?

  git::create_or_update_mirror "${sopka_remote_url}" sopka.git || softfail || return $?

  ( cd "${sopka_path}" && git::add_or_update_remote "offline-install" "${current_directory}/sopka.git" && git fetch "offline-install" ) || softfail || return $?

  dir::make_if_not_exists "sopkafiles" || softfail || return $?

  local sopkafile_path; for sopkafile_path in "${sopka_path}/sopkafiles"/*; do
    if [ -d "${sopkafile_path}" ]; then
      local sopkafile_dir_name; sopkafile_dir_name="$(basename "${sopkafile_path}")" || softfail || return $?
      local sopkafile_remote_url; sopkafile_remote_url="$(git -C "${sopkafile_path}" remote get-url origin)" || softfail || return $?

      git::create_or_update_mirror "${sopkafile_remote_url}" "sopkafiles/${sopkafile_dir_name}" || softfail || return $?

      ( cd "${sopkafile_path}" && git::add_or_update_remote "offline-install" "${current_directory}/sopkafiles/${sopkafile_dir_name}" && git fetch "offline-install" ) || softfail || return $?
    fi
  done

  cp -f "${sopka_path}/src/deploy-offline.sh" . || softfail || return $?
}

# it will dump all current sopkafiles, not a good idea
# is systemwide-install the good idea at all?
#
# sopka::install_systemwide() {
#   local temp_file; temp_file="$(mktemp)" || softfail || return $?
#
#   file::get_block "${SOPKA_BIN_PATH}" set_shell_options >>"${temp_file}" || softfail || return $?
#
#   declare -f >>"${temp_file}" || softfail || return $?
#
#   file::get_block "${SOPKA_BIN_PATH}" invoke_sopkafile >>"${temp_file}" || softfail || return $?
#
#   sudo install -m 755 -o root -g root "${temp_file}" /usr/local/bin/sopka.tmp || softfail || return $?
#
#   sudo mv /usr/local/bin/sopka.tmp /usr/local/bin/sopka || softfail || return $?
#
#   rm "${temp_file}" || softfail || return $?
# }
