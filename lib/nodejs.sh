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

# Get a version number: nodenv install --list | grep ^14
nodejs::install-by-nodenv-and-set-global() {
  local nodeVersion="$1"
  nodejs::install-by-nodenv "${nodeVersion}" || softfail || return $?
  nodenv global "${nodeVersion}" || softfail || return $?
}

nodejs::install-by-nodenv() {
  local nodeVersion="${1:-}"

  nodenv::install-and-load-shellrc || softfail || return $?
  nodenv::install-nodejs "${nodeVersion:-}" || softfail || return $?

  # this will set NODENV_VERSION to the last element of ARGV array
  # shellcheck disable=2124
  NODENV_VERSION="${nodeVersion:-"${NODENV_VERSION:-}"}" nodenv::configure-mismatched-binaries-workaround || softfail || return $?
}

nodejs::install-by-apt() {
  local version="$1"

  local distributionCodename; distributionCodename="$(lsb_release --codename --short)" || softfail || return $?

  apt::add-key-and-source "https://deb.nodesource.com/gpgkey/nodesource.gpg.key" \
    "deb https://deb.nodesource.com/node_${version}.x ${distributionCodename} main" "nodesource" || softfail || return $?

  apt::update || softfail || return $?
  apt::install nodejs || softfail || return $?
}

nodejs::install-yarn-by-apt() {
  apt::add-key-and-source "https://dl.yarnpkg.com/debian/pubkey.gpg" "deb https://dl.yarnpkg.com/debian/ stable main" "yarn" || softfail "Unable to add yarn apt source" || return $?

  apt::update || softfail || return $?
  apt::install yarn || softfail || return $?
}

npm::update-system-wide-packages() {
  sudo NODENV_VERSION=system npm update -g --unsafe-perm=true || softfail || return $?
}

# bitwarden::use password "test record" npm::auth-token registry.npmjs.org
#
npm::auth-token::exists() {
  local registry="${1:-"registry.npmjs.org"}"
  test -f "${HOME}/.npmrc" || return 1
  grep -qF "//${registry}/:_authToken" "${HOME}/.npmrc"
}

npm::auth-token::save() {
  local token="$1"
  local registry="${2:-"registry.npmjs.org"}"
  
  npm set "//${registry}/:_authToken" "${token}" || softfail || return $?
}
