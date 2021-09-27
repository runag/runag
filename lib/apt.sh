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
    SOPKA_APT_LAZY_UPDATE_HAPPENED=true
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
  SOPKA_APT_LAZY_UPDATE_HAPPENED=true
  sudo apt-get -qq -o Acquire::ForceIPv4=true update || fail
}

# @description Perform apt dist-upgrade
apt::dist-upgrade() {
  sudo apt-get -qq -y -o Acquire::ForceIPv4=true dist-upgrade | apt::shush
  test "${PIPESTATUS[*]}" = "0 0" || fail
}

# @description Install package
apt::install() {
  sudo apt-get -qq -y -o Acquire::ForceIPv4=true install "$@" | apt::shush
  test "${PIPESTATUS[*]}" = "0 0" || fail
}

# @description Perform apt autoremove
apt::autoremove() {
  sudo apt-get -qq -y -o Acquire::ForceIPv4=true autoremove | apt::shush
  test "${PIPESTATUS[*]}" = "0 0" || fail
}

# @description Shush the apt
apt::shush() {
  if [ "${SOPKA_VERBOSE:-}" = true ]; then
    tee || fail
  else
    grep -vE "\
^Selecting previously unselected package|\
^\\(Reading database \\.\\.\\.|\
^Preparing to unpack .* \\.\\.\\.|\
^Unpacking .* \\.\\.\\.|\
^Setting up .* \\.\\.\\.|\
^Processing triggers for .* \\.\\.\\.|\
^Removing .* \\.\\.\\.|\
^Preconfiguring packages \\.\\.\\.|\
^Extracting templates from packages: 100%|\
^update-alternatives: using .* to provide .* in auto mode|\
^Purging old database entries in .*\\.\\.\\.|\
^Processing manual pages under .*\\.\\.\\.|\
^Checking for stray cats under .*\\.\\.\\.|\
^[[:digit:]]+ man subdirectory contained newer manual pages\\.|\
^[[:digit:]]+ manual page was added\\.|\
^[[:digit:]]+ stray cats were added\\.|\
^[[:digit:]]+ old database entries were purged\\."
    
    if [ "$?" -ge "2" ]; then
      fail
    fi
  fi
}

# @description Add apt source and key
#
# @example
#    apt::add-key-and-source "https://dl.yarnpkg.com/debian/pubkey.gpg" "deb https://dl.yarnpkg.com/debian/ stable main" "yarn" | fail
#
# @arg $1 string key url
# @arg $2 string source string
# @arg $3 string source name for sources.list.d
apt::add-key-and-source() {
  local keyUrl="$1"
  local sourceString="$2"
  local sourceName="$3"

  local sourceFile="/etc/apt/sources.list.d/${sourceName}.list"

  curl --fail --silent --show-error "${keyUrl}" | sudo apt-key add -
  test "${PIPESTATUS[*]}" = "0 0" || fail "Unable to get key from ${keyUrl} or import in into apt"

  echo "${sourceString}" | sudo tee "${sourceFile}" >/dev/null || fail "Unable to write apt source into the ${sourceFile}"
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
