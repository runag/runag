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
    sudo cp "${SOPKA_SRC_DIR}/lib/macos/limit.maxfiles.plist" "${dst}" || fail "Unable to copy to $dst ($?)"

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

macos::hide-folder() {
  if [ -d "$1" ]; then
    chflags hidden "$1" || fail
  fi
}
