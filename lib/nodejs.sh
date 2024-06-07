#!/usr/bin/env bash

#  Copyright 2012-2024 Rùnag project contributors
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

nodejs::install_dependencies::apt() {
  # https://asdf-vm.com/guide/getting-started.html#plugin-dependencies
  apt::install \
    curl    `# asdf-specific` \
    dirmngr `# asdf-specific` \
    gawk    `# asdf-specific` \
    gpg     `# asdf-specific` \
      || softfail || return $?
}

nodejs::install::apt() (
  local version="$1"

  . /etc/os-release || softfail || return $?

  apt::add_source_with_key "nodesource" \
    "https://deb.nodesource.com/node_${version}.x ${VERSION_CODENAME} main" \
    "https://deb.nodesource.com/gpgkey/nodesource.gpg.key" || softfail || return $?

  apt::install nodejs || softfail || return $?
)

nodejs::install_yarn::apt() {
  apt::add_source_with_key "yarnpkg" \
    "https://dl.yarnpkg.com/debian/ stable main" \
    "https://dl.yarnpkg.com/debian/pubkey.gpg" || softfail "Unable to add yarn apt source" || return $?

  apt::install yarn || softfail || return $?
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
    file::append_line_unless_present --keep-permissions ".gitignore" "/.npmrc" || softfail || return $?
    
    if [ -f .npmignore ]; then
      file::append_line_unless_present --keep-permissions ".npmignore" "/.npmrc" || softfail || return $?
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
