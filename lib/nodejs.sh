#!/usr/bin/env bash

#  Copyright 2012-2025 Runag project contributors
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

# https://asdf-vm.com/guide/getting-started.html#plugin-dependencies
# https://github.com/nodejs/node/blob/main/BUILDING.md#building-nodejs-on-supported-platforms

nodejs::extend_package_list::debian() {
  package_list+=(
    curl # asdf requires that
    dirmngr # asdf requires that
    gawk # asdf requires that
    gpg # asdf requires that
  )
}

nodejs::extend_package_list::arch() {
  package_list+=(
    curl # asdf requires that
    gawk # asdf requires that
    gnupg # asdf requires that, dirmngr is in gnupg
  )
}

nodejs::add_apt_source() {
  local version="$1"
  apt::add_source_with_key "nodesource" \
    "https://deb.nodesource.com/node_${version}.x nodistro main" \
    "https://deb.nodesource.com/gpgkey/nodesource.gpg.key" || softfail "Unable to add nodejs apt source" || return $?
}

nodejs::add_yarn_apt_source() {
  apt::add_source_with_key "yarnpkg" \
    "https://dl.yarnpkg.com/debian/ stable main" \
    "https://dl.yarnpkg.com/debian/pubkey.gpg" || softfail "Unable to add yarn apt source" || return $?
}

# npm

npm::update_globally_installed_packages() {
  sudo NODENV_VERSION=system npm update -g --unsafe-perm=true || softfail || return $?
}

npm::auth_token() {
  local registry="registry.npmjs.org"
  local project_config

  while [ "$#" -gt 0 ]; do
    case "$1" in
      -r|--registry)
        registry="$2"
        shift; shift
        ;;
      -l|--project)
        project_config=true
        shift
        ;;
      -*)
        softfail "Unknown argument: $1" || return $?
        ;;
      *)
        break
        ;;
    esac
  done

  local token="$1"

  if [ "${project_config:-}" = true ]; then
    file::write --append-line-unless-present ".gitignore" "/.npmrc" || softfail || return $?
    
    if [ -f .npmignore ]; then
      file::write --append-line-unless-present ".npmignore" "/.npmrc" || softfail || return $?
    fi
  fi

  npm config set ${project_config:+"--location" "project"} "//${registry}/:_authToken" "${token}" || softfail || return $?

  # According to that documentation, .npmrc should have mode 0600
  # https://npm.github.io/installation-setup-docs/customizing/the-npmrc-file.html
  #
  # "npm config set" creates a file with mode rw-rw-rw- and I don't know how to prevent that
  # setting umask 0177 for "npm config set" does not help

  chmod 0600 ".npmrc" || softfail || return $?
}
