#!/usr/bin/env bash

#  Copyright 2012-2021 Stanislav Senotrusov <stan@senotrusov.com>
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

nodejs::apt::add-source() {
  local version="${1:-14}"

  local distributionCodename; distributionCodename="$(lsb_release --codename --short)" || fail

  apt::add-key-and-source "https://deb.nodesource.com/gpgkey/nodesource.gpg.key" \
    "deb https://deb.nodesource.com/node_${version}.x ${distributionCodename} main" "nodesource" || fail
}

nodejs::apt::install() {
  nodejs::apt::add-source "$@" || fail
  apt::update || fail
  apt::install nodejs || fail
}

nodejs::apt::add-yarn-source() {
  apt::add-key-and-source "https://dl.yarnpkg.com/debian/pubkey.gpg" "deb https://dl.yarnpkg.com/debian/ stable main" "yarn" || fail "Unable to add yarn apt source"
}

nodejs::apt::install-yarn() {
  nodejs::apt::add-yarn-source || fail
  apt::update || fail
  apt::install yarn || fail
}

nodejs::install-and-load-nodenv() {
  nodejs::install-nodenv || fail
  nodejs::load-nodenv || fail
}

nodejs::install-nodenv() {
  nodejs::install-nodenv-repositories || fail
  nodejs::install-nodenv-shellrc || fail
  nodejs::configure-mismatched-binaries-workaround || fail
}

nodejs::configure-mismatched-binaries-workaround() {
  # https://github.com/nodenv/nodenv/wiki/FAQ#npm-warning-about-mismatched-binaries
  NODENV_VERSION=system npm config set scripts-prepend-node-path auto || fail
}

nodejs::install-nodenv-repositories() {
  local nodenvRoot="${HOME}/.nodenv"

  git::place-up-to-date-clone "https://github.com/nodenv/nodenv.git" "${nodenvRoot}" || fail

  dir::make-if-not-exists "${nodenvRoot}/plugins" || fail
  git::place-up-to-date-clone "https://github.com/nodenv/node-build.git" "${nodenvRoot}/plugins/node-build" || fail
}

nodejs::install-nodenv-shellrc() {
  if [ -n "${1:-}" ]; then
    local output="$1"
  else
    local output; output="$(shell::get-shellrc-filename "nodenv")" || fail
  fi

  file::write "${output}" 600 <<SHELL || fail
$(sopka::print-license)

if [ -d "\${HOME}/.nodenv/bin" ]; then
  if ! [[ ":\${PATH}:" == *":\${HOME}/.nodenv/bin:"* ]]; then
    export PATH="\${HOME}/.nodenv/bin:\${PATH}"
  fi
fi

if command -v nodenv >/dev/null; then
  if [ -z \${SOPKA_NODENV_INITIALIZED+x} ]; then
    eval "\$(nodenv init -)" || { echo "Unable to init nodenv" >&2; return 1; }
    export SOPKA_NODENV_INITIALIZED=true
  fi
fi
SHELL
}

nodejs::load-nodenv() {
  shell::load-shellrc "nodenv" || fail
  nodenv rehash || fail
}

nodejs::update-globally-installed-packages() {
  sudo NODENV_VERSION=system npm update -g --unsafe-perm=true || fail
}

# bitwarden::use password "test record" nodejs::auth-token registry.npmjs.org

nodejs::auth-token::exists(){
  local registry="${1:-"registry.npmjs.org"}"
  test -f "${HOME}/.npmrc" || return 1
  grep -qF "//${registry}/:_authToken" "${HOME}/.npmrc"
}

nodejs::auth-token::save(){
  local token="$1"
  local registry="${2:-"registry.npmjs.org"}"
  
  NODENV_VERSION=system npm set "//${registry}/:_authToken" "${token}" || fail
}
