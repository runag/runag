#!/usr/bin/env bash

#  Copyright 2012-2022 Rùnag project contributors
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

# ---- install dependencies ----

nodejs::install_dependencies::apt() {
  # https://asdf-vm.com/guide/getting-started.html#plugin-dependencies
  apt::install \
    curl    `# asdf-specific` \
    dirmngr `# asdf-specific` \
    gawk    `# asdf-specific` \
    gpg     `# asdf-specific` \
      || softfail || return $?
}


# ---- install by asdf ----

nodejs::install_by_asdf() {
  local node_version="${1:-"latest"}"

  asdf::add_plugin nodejs || softfail || return $?

  asdf install nodejs "${node_version}" || softfail || return $?
}

nodejs::install_by_asdf_and_set_global() {
  local node_version="${1:-"latest"}"

  nodejs::install_by_asdf "${node_version}" || softfail || return $?
  asdf global nodejs "${node_version}" || softfail || return $?
}


# ---- install by nodenv ----

# Get a version number: nodenv install --list | grep ^14

nodejs::install_by_nodenv() {
  local node_version="${1:-}"

  nodenv::install_nodejs "${node_version:-}" || softfail || return $?

  # this will set NODENV_VERSION to the last element of ARGV array
  # shellcheck disable=2124
  NODENV_VERSION="${node_version:-"${NODENV_VERSION:-}"}" nodenv::configure_mismatched_binaries_workaround || softfail || return $?
}

nodejs::install_by_nodenv_and_set_global() {
  local node_version="${1:-"${NODENV_VERSION}"}"

  nodejs::install_by_nodenv "${node_version}" || softfail || return $?
  nodenv global "${node_version}" || softfail || return $?
}


# ---- install by apt ----

nodejs::install::apt() {
  local version="$1"

  local distribution_codename; distribution_codename="$(lsb_release --codename --short)" || softfail || return $?

  apt::add_source_with_key "nodesource" \
    "https://deb.nodesource.com/node_${version}.x ${distribution_codename} main" \
    "https://deb.nodesource.com/gpgkey/nodesource.gpg.key" || softfail || return $?

  apt::install nodejs || softfail || return $?
}

nodejs::install_yarn::apt() {
  apt::add_source_with_key "yarnpkg" \
    "https://dl.yarnpkg.com/debian/ stable main" \
    "https://dl.yarnpkg.com/debian/pubkey.gpg" || softfail "Unable to add yarn apt source" || return $?

  apt::install yarn || softfail || return $?
}

npm::update_globally_installed_packages() {
  sudo NODENV_VERSION=system npm update -g --unsafe-perm=true || softfail || return $?
}


# ---- npm auth_token ----

# bitwarden::use password "test record" npm::auth_token registry.npmjs.org
#
npm::auth_token::exists() {
  local registry="registry.npmjs.org"

  test -f "${HOME}/.npmrc" || return 1
  grep -qF "//${registry}/:_authToken" "${HOME}/.npmrc"
}

npm::auth_token() {
  local token="$1"

  local registry="registry.npmjs.org" # TODO: optional argument
  
  npm set "//${registry}/:_authToken" "${token}" || softfail || return $?
}
