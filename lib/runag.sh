#!/usr/bin/env bash

#  Copyright 2012-2024 Rùnag project contributors
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

runag::mini_library() {
  cat <<SHELL || softfail || return $?
#!/usr/bin/env bash

$(runag::print_license)

$(declare -f fail)
$(declare -f softfail)
$(declare -f dir::should_exists)
$(declare -f file::write)
SHELL
}

runag::print_license() {
  cat <<SHELL
#  Copyright 2012-2024 Rùnag project contributors
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

runag::menu() {
  if [ -d "${HOME}/.runag" ]; then
    menu::add --header "Rùnag and rùnagfiles" || softfail || return $?
    
    menu::add runag::pull || softfail || return $?
    menu::add runag::push || softfail || return $?
    menu::add runag::create_or_update_offline_install "$(pwd)" || softfail || return $?
    menu::add runag::update_current_offline_install_if_connected || softfail || return $?
  fi
}

runag::pull() {
  if [ -d "${HOME}/.runag/.git" ]; then
    git -C "${HOME}/.runag" pull || softfail || return $?
  fi

  runagfile::each git pull || softfail || return $?
}

runag::push() {
  if [ -d "${HOME}/.runag/.git" ]; then
    git -C "${HOME}/.runag" push || softfail || return $?
  fi

  runagfile::each git push || softfail || return $?
}

runag::is_current_offline_install_connected() {
  local runag_path="${HOME}/.runag"

  if [ ! -d "${runag_path}/.git" ]; then
    fail "Unable to find rùnag checkout" # fail here is intentional
  fi

  local remote_path

  if remote_path="$(git -C "${runag_path}" config "remote.offline-install.url")"; then
    if [ -d "${remote_path}" ]; then
      return 0
    fi
  fi

  return 1
}

runag::update_current_offline_install_if_connected() {
  local runag_path="${HOME}/.runag"

  if [ ! -d "${runag_path}/.git" ]; then
    softfail "Unable to find rùnag checkout" || return $?
  fi

  local remote_path
  
  if remote_path="$(git -C "${runag_path}" config "remote.offline-install.url")"; then
    if [ -d "${remote_path}" ]; then
      runag::create_or_update_offline_install "${remote_path}/.." || softfail || return $?
    fi
  fi
}

runag::create_or_update_offline_install() (
  local target_directory="${1:-"."}"

  cd "${target_directory}" || softfail || return $?

  target_directory="$(pwd)" || softfail || return $?

  local runag_path="${HOME}/.runag"

  if [ ! -d "${runag_path}/.git" ]; then
    softfail "Unable to find rùnag checkout" || return $?
  fi

  local runag_remote_url; runag_remote_url="$(git -C "${runag_path}" remote get-url origin)" || softfail || return $?

  git -C "${runag_path}" pull origin main || softfail || return $?
  git -C "${runag_path}" push origin main || softfail || return $?

  git::create_or_update_mirror "${runag_remote_url}" runag.git || softfail || return $?

  ( cd "${runag_path}" && git::add_or_update_remote "offline-install" "${target_directory}/runag.git" && git fetch "offline-install" ) || softfail || return $?

  dir::should_exists --mode 0700 "runagfiles" || softfail || return $?

  local runagfile_path; for runagfile_path in "${runag_path}/runagfiles"/*; do
    if [ -d "${runagfile_path}" ]; then
      local runagfile_dir_name; runagfile_dir_name="$(basename "${runagfile_path}")" || softfail || return $?
      local runagfile_remote_url; runagfile_remote_url="$(git -C "${runagfile_path}" remote get-url origin)" || softfail || return $?

      git -C "${runagfile_path}" pull origin main || softfail || return $?
      git -C "${runagfile_path}" push origin main || softfail || return $?

      git::create_or_update_mirror "${runagfile_remote_url}" "runagfiles/${runagfile_dir_name}" || softfail || return $?

      ( cd "${runagfile_path}" && git::add_or_update_remote "offline-install" "${target_directory}/runagfiles/${runagfile_dir_name}" && git fetch "offline-install" ) || softfail || return $?
    fi
  done

  cp -f "${runag_path}/scripts/deploy-offline.sh" . || softfail || return $?
)
