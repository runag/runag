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

runag::print_license() {
  cat <<SHELL
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
SHELL
}

runag::runagfile_menu() {
  if [ -d "${HOME}/.runag" ]; then
    runagfile_menu::add --header "Rùnag and rùnagfiles" || softfail || return $?
    
    runagfile_menu::add runag::create_or_update_offline_install || softfail || return $?
    runagfile_menu::add runag::update || softfail || return $?
  fi
}

runag::update() {
  if [ -d "${HOME}/.runag/.git" ]; then
    git -C "${HOME}/.runag" pull || softfail || return $?
  fi

  runagfile::update-everything-in-runag || softfail || return $?
}

runag::create_or_update_offline_install() {
  local runag_path="${HOME}"/.runag

  if [ ! -d "${runag_path}/.git" ]; then
    softfail "Unable to find rùnag checkout" || return $?
  fi

  local current_directory; current_directory="$(pwd)" || softfail || return $?

  local runag_remote_url; runag_remote_url="$(git -C "${runag_path}" remote get-url origin)" || softfail || return $?

  git::create_or_update_mirror "${runag_remote_url}" runag.git || softfail || return $?

  ( cd "${runag_path}" && git::add_or_update_remote "offline-install" "${current_directory}/runag.git" && git fetch "offline-install" ) || softfail || return $?

  dir::make_if_not_exists "runagfiles" || softfail || return $?

  local runagfile_path; for runagfile_path in "${runag_path}/runagfiles"/*; do
    if [ -d "${runagfile_path}" ]; then
      local runagfile_dir_name; runagfile_dir_name="$(basename "${runagfile_path}")" || softfail || return $?
      local runagfile_remote_url; runagfile_remote_url="$(git -C "${runagfile_path}" remote get-url origin)" || softfail || return $?

      git::create_or_update_mirror "${runagfile_remote_url}" "runagfiles/${runagfile_dir_name}" || softfail || return $?

      ( cd "${runagfile_path}" && git::add_or_update_remote "offline-install" "${current_directory}/runagfiles/${runagfile_dir_name}" && git fetch "offline-install" ) || softfail || return $?
    fi
  done

  cp -f "${runag_path}/src/deploy-offline.sh" . || softfail || return $?
}

# it will dump all current runagfiles, not a good idea
# is systemwide-install a good idea at all?
#
# runag::install_systemwide() {
#   local temp_file; temp_file="$(mktemp)" || softfail || return $?
#
#   file::get_block "${RUNAG_BIN_PATH}" set_shell_options >>"${temp_file}" || softfail || return $?
#
#   declare -f >>"${temp_file}" || softfail || return $?
#
#   file::get_block "${RUNAG_BIN_PATH}" invoke_runagfile >>"${temp_file}" || softfail || return $?
#
#   sudo install -m 755 -o root -g root "${temp_file}" /usr/local/bin/runag.tmp || softfail || return $?
#
#   sudo mv /usr/local/bin/runag.tmp /usr/local/bin/runag || softfail || return $?
#
#   rm "${temp_file}" || softfail || return $?
# }
