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

nodejs::ubuntu::install() {
  apt::add-yarn-source || fail
  apt::add-nodejs-source || fail
  apt::update || fail
  apt::install yarn nodejs || fail
  nodejs::install-nodenv || fail
  shellrcd::nodenv || fail
  nodenv rehash || fail
  sudo npm update -g || fail
}

nodejs::install-nodenv() {
  local nodenvRoot="${HOME}/.nodenv"
  git::clone-or-pull "https://github.com/nodenv/nodenv.git" "${nodenvRoot}" || fail
  mkdir -p "${nodenvRoot}/plugins" || fail
  git::clone-or-pull "https://github.com/nodenv/node-build.git" "${nodenvRoot}/plugins/node-build" || fail
}

shellrcd::nodenv() {
  local output="${HOME}/.shellrc.d/nodenv.sh"
  fs::write-file "${output}" <<SHELL || fail
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
}

apt::add-nodejs-source() {
  local version="${1:-14}"
  curl --location --fail --silent --show-error "https://deb.nodesource.com/setup_${version}.x" | sudo -E bash -
  test "${PIPESTATUS[*]}" = "0 0" || fail "Unable to run nodejs install script"
}

apt::add-yarn-source() {
  apt::add-key-and-source "https://dl.yarnpkg.com/debian/pubkey.gpg" "deb https://dl.yarnpkg.com/debian/ stable main" "yarn" || fail "Unable to add yarn apt source"
}
