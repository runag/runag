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

shellrcd::nodenv() {
  local output="${HOME}/.shellrc.d/nodenv.sh"

  tee "${output}" <<SHELL || fail "Unable to write file: ${output} ($?)"
    if [ -d "\$HOME/.nodenv/bin" ]; then
      if ! [[ ":\$PATH:" == *":\$HOME/.nodenv/bin:"* ]]; then
        export PATH="\$HOME/.nodenv/bin:\$PATH"
      fi
    fi
    if command -v nodenv >/dev/null; then
      if [ -z \${NODENV_INITIALIZED+x} ]; then
        eval "\$(nodenv init -)" || { echo "Unable to init nodenv" >&2; return 1; }
        export NODENV_INITIALIZED=true
      fi
    fi
SHELL

  . "${output}" || fail
  nodenv rehash || fail
}

apt::add-nodejs-source() {
  # Please use only even-numbered nodejs releases here, they are LTS
  local nodejsInstallerUrl="https://deb.nodesource.com/setup_12.x"
  curl --location --fail --silent --show-error "${nodejsInstallerUrl}" | sudo -E bash -
  test "${PIPESTATUS[*]}" = "0 0" || fail "Unable to curl ${nodejsInstallerUrl} | bash"
}

apt::add-yarn-source() {
  apt::add-key-and-source "https://dl.yarnpkg.com/debian/pubkey.gpg" "deb https://dl.yarnpkg.com/debian/ stable main" "yarn" || fail "Unable to add yarn apt source"
}
