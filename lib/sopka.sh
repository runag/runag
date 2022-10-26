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

sopka::install_as_repository_clone() {
  git::place_up_to_date_clone "https://github.com/senotrusov/sopka.git" "${HOME}/.sopka" || softfail || return $?
}

sopka::update() {
  if [ -d "${HOME}/.sopka/.git" ]; then
    git -C "${HOME}/.sopka" pull || softfail || return $?
  fi

  sopkafile::update-everything-in-sopka || softfail || return $?
}

# it will dump all current sopkafiles, not a good idea
# is systemwide-install the good idea at all?

# sopka::install_systemwide() {
#   local temp_file; temp_file="$(mktemp)" || softfail || return $?

#   file::get_block "${SOPKA_BIN_PATH}" set_shell_options >>"${temp_file}" || softfail || return $?

#   declare -f >>"${temp_file}" || softfail || return $?

#   file::get_block "${SOPKA_BIN_PATH}" invoke_sopkafile >>"${temp_file}" || softfail || return $?

#   sudo install -m 755 -o root -g root "${temp_file}" /usr/local/bin/sopka.tmp || softfail || return $?

#   sudo mv /usr/local/bin/sopka.tmp /usr/local/bin/sopka || softfail || return $?

#   rm "${temp_file}" || softfail || return $?
# }


sopka::make_local_copy() {(
  local dest_path="${1:-"sopka"}"

  local source_path="${HOME}/.sopka"

  if [ -d "${dest_path}" ]; then
    softfail "Already exists: ${dest_path}" || return $?
  fi

  cp -R "${source_path}" "${dest_path}" || softfail || return $?

  local dest_full_path; dest_full_path="$(cd "${dest_path}" >/dev/null 2>&1 && pwd)" || softfail || return $?

  ( 
    cd "${dest_path}" || softfail || return $?

    sopka::make_local_copy::configure_copy || softfail || return $?

    local sopkafile_path; for sopkafile_path in sopkafiles/*; do
      if [ -d "${sopkafile_path}" ]; then
        (
          cd "${sopkafile_path}" || softfail || return $?
          sopka::make_local_copy::configure_copy || softfail || return $?
        ) || softfail || return $?
      fi
    done
  ) || softfail || return $?

  ( 
    cd "${source_path}" || softfail || return $?

    sopka::make_local_copy::configure_source "${dest_full_path}" || softfail || return $?

    local sopkafile_path; for sopkafile_path in sopkafiles/*; do
      if [ -d "${sopkafile_path}" ]; then
        (
          cd "${sopkafile_path}" || softfail || return $?
          sopka::make_local_copy::configure_source "${dest_full_path}/${sopkafile_path}" || softfail || return $?
        ) || softfail || return $?
      fi
    done
  ) || softfail || return $?
)}

sopka::make_local_copy::configure_copy() {
  git config receive.denyCurrentBranch updateInstead || softfail || return $?

  if git remote get-url local-copy >/dev/null 2>&1; then
    git remote remove local-copy || softfail || return $?
  fi
}

sopka::make_local_copy::configure_source() {
  if git remote get-url local-copy >/dev/null 2>&1; then
    git remote set-url local-copy "$1" || softfail || return $?
  else
    git remote add local-copy "$1" || softfail || return $?
  fi
}
