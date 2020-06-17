#!/usr/bin/env bash

#  Copyright 2012-2019 Stanislav Senotrusov <stan@senotrusov.com>
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

macos::increase-maxfiles-limit() {
  # based on https://unix.stackexchange.com/questions/108174/how-to-persistently-control-maximum-system-resource-consumption-on-mac

  local dst="/Library/LaunchDaemons/limit.maxfiles.plist"

  if [ ! -f "${dst}" ]; then
    sudo cp "${STAN_DEPLOY_LIB_DIR}/lib/macos/limit.maxfiles.plist" "${dst}" || fail "Unable to copy to $dst ($?)"

    sudo chmod 0644 "${dst}" || fail "Unable to chmod ${dst} ($?)"

    sudo chown root:wheel "${dst}" || fail "Unable to chown ${dst} ($?)"

    echo "increase-maxfiles-limit: Please reboot your computer" >&2
  fi
}

macos::install-homebrew() {
  if ! command -v brew >/dev/null; then
    /usr/bin/ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)" </dev/null || fail "Unable to install homebrew"
  fi
}

macos::ssh::add-use-keychain-to-ssh-config() {
  local sshConfigFile="${HOME}/.ssh/config"

  if [ ! -f "${sshConfigFile}" ]; then
    touch "${sshConfigFile}" || fail
  fi

  if grep --quiet "^# Use keychain" "${sshConfigFile}"; then
    echo "Use keychain config already present"
  else
tee -a "${sshConfigFile}" <<SHELL || fail "Unable to append to the file: ${sshConfigFile}"

# Use keychain
Host *
  UseKeychain yes
  AddKeysToAgent yes
SHELL
  fi
}

macos::ssh::add-ssh-key-password-to-keychain() {
  local keyFile="${HOME}/.ssh/id_rsa"
  if ssh-add -L | grep --quiet --fixed-strings "${keyFile}"; then
    echo "${keyFile} is already in the keychain"
  else
    deploy-lib::bitwarden::unlock || fail

    # I could not pipe output directly to ssh-add because "bw get password" throws a pipe error in that case
    local password; password="$(bw get password "my current password for ssh private key")" || fail
    echo "${password}" | SSH_ASKPASS="${STAN_DEPLOY_LIB_DIR}/lib/macos/exec-cat.sh" DISPLAY=1 ssh-add -K "${keyFile}"
    test "${PIPESTATUS[*]}" = "0 0" || fail "Unable to obtain and store ssh key password"
  fi
}

macos::hide-folder() {
  if [ -d "$1" ]; then
    chflags hidden "$1" || fail
  fi
}
