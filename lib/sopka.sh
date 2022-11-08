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
