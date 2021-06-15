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

# @description Perform apt update once per script run
apt::lazy-update() {
  if [ -z "${SOPKA_APT_LAZY_UPDATE_HAPPENED:-}" ]; then
    SOPKA_APT_LAZY_UPDATE_HAPPENED=1
    apt::update || fail
  fi
}

# @description Perform apt update once per script run, and then perform apt dist-upgrade
apt::lazy-update-and-dist-upgrade() {
  apt::lazy-update || fail
  apt::dist-upgrade || fail
}

# @description Perform apt update
apt::update() {
  SOPKA_APT_LAZY_UPDATE_HAPPENED=1
  sudo apt-get -o Acquire::ForceIPv4=true update || fail "Unable to apt-get update ($?)"
}

# @description Perform apt dist-upgrade
apt::dist-upgrade() {
  sudo apt-get -o Acquire::ForceIPv4=true -y dist-upgrade || fail "Unable to apt-get dist-upgrade ($?)"
}

# @description Install package
apt::install() {
  sudo apt-get install -o Acquire::ForceIPv4=true -y "$@" || fail "Unable to apt-get install $* ($?)"
}

# @description Perform apt autoremove
apt::autoremove() {
  sudo apt-get -o Acquire::ForceIPv4=true -y autoremove || fail "Unable to apt-get autoremove ($?)"
}

# @description Add apt source and key
#
# @example
#    apt::add-key-and-source "https://dl.yarnpkg.com/debian/pubkey.gpg" "deb https://dl.yarnpkg.com/debian/ stable main" "yarn" | fail
#
# @arg $1 string key url
# @arg $2 string source string
# @arg $3 string source name
apt::add-key-and-source() {
  local keyUrl="$1"
  local sourceString="$2"
  local sourceName="$3"
  local sourceFile="/etc/apt/sources.list.d/${sourceName}.list"

  curl --fail --silent --show-error "${keyUrl}" | sudo apt-key add -
  test "${PIPESTATUS[*]}" = "0 0" || fail "Unable to get key from ${keyUrl} or import in into apt"

  echo "${sourceString}" | sudo tee "${sourceFile}" || fail "Unable to write apt source into the ${sourceFile}"
}

# gnome-keyring and libsecret (for git and ssh)
apt::install-gnome-keyring-and-libsecret() {
  apt::install \
    gnome-keyring \
    libsecret-tools \
    libsecret-1-0 \
    libsecret-1-dev \
      || fail
}

apt::install-tools() {
  apt::install \
    curl \
    debian-goodies `# checkrestart is in there` \
    direnv \
    git \
    jq `# for use with bitwarden` \
    sysbench \
      || fail
}
