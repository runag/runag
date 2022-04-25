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

# Get a version number: nodenv install --list | grep ^14
nodejs::install_by_nodenv_and_set_global() {
  local node_version="${1:-"${NODENV_VERSION}"}"

  nodejs::install_by_nodenv "${node_version}" || softfail || return $?
  nodenv global "${node_version}" || softfail || return $?
}

nodejs::install_by_nodenv() {
  local node_version="${1:-}"

  nodenv::install_and_load_shellrc || softfail || return $?
  nodenv::install_nodejs "${node_version:-}" || softfail || return $?

  # this will set NODENV_VERSION to the last element of ARGV array
  # shellcheck disable=2124
  NODENV_VERSION="${node_version:-"${NODENV_VERSION:-}"}" nodenv::configure_mismatched_binaries_workaround || softfail || return $?
}

nodejs::install_by_apt() {
  local version="$1"

  local distribution_codename; distribution_codename="$(lsb_release --codename --short)" || softfail || return $?

  apt::add_key_and_source "https://deb.nodesource.com/gpgkey/nodesource.gpg.key" \
    "deb https://deb.nodesource.com/node_${version}.x ${distribution_codename} main" "nodesource" || softfail || return $?

  apt::update || softfail || return $?
  apt::install nodejs || softfail || return $?
}

nodejs::install_yarn_by_apt() {
  apt::add_key_and_source "https://dl.yarnpkg.com/debian/pubkey.gpg" "deb https://dl.yarnpkg.com/debian/ stable main" "yarn" || softfail "Unable to add yarn apt source" || return $?

  apt::update || softfail || return $?
  apt::install yarn || softfail || return $?
}

npm::update_system_wide_packages() {
  sudo NODENV_VERSION=system npm update -g --unsafe-perm=true || softfail || return $?
}

# bitwarden::use password "test record" npm::auth_token registry.npmjs.org
#
npm::auth_token::exists() {
  local registry="${1:-"registry.npmjs.org"}"

  test -f "${HOME}/.npmrc" || return 1
  grep -qF "//${registry}/:_authToken" "${HOME}/.npmrc"
}

npm::auth_token::save() {
  local token="$1"
  local registry="${2:-"registry.npmjs.org"}"
  
  npm set "//${registry}/:_authToken" "${token}" || softfail || return $?
}
