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

apt::autoremove_lazy_update_and_maybe_dist_upgrade() {
  apt::autoremove || softfail || return $?

  apt::lazy_update || softfail || return $?

  if [ "${CI:-}" != "true" ]; then
    apt::dist_upgrade || softfail || return $?
  fi
}

# @description Perform apt update once per script run
apt::lazy_update() {
  if [ -z "${SOPKA_APT_LAZY_UPDATE_HAPPENED:-}" ]; then
    SOPKA_APT_LAZY_UPDATE_HAPPENED=true
    apt::update || fail
  fi
}

# @description Perform apt update once per script run, and then perform apt dist-upgrade
apt::lazy_update_and_dist_upgrade() {
  apt::lazy_update || fail
  apt::dist_upgrade || fail
}

# @description Perform apt update
apt::update() {
  SOPKA_APT_LAZY_UPDATE_HAPPENED=true
  sudo DEBIAN_FRONTEND=noninteractive apt-get update || fail
}

# @description Perform apt dist-upgrade
apt::dist_upgrade() {
  # TODO: Check if this Dpkg::Options are good defaults
  sudo DEBIAN_FRONTEND=noninteractive apt-get -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" -y dist-upgrade || fail
}

# @description Install package
apt::install() {
  sudo DEBIAN_FRONTEND=noninteractive apt-get -y install "$@" || fail
}

apt::remove() {
  sudo DEBIAN_FRONTEND=noninteractive apt-get -y remove "$@" || fail
}

# @description Perform apt autoremove
apt::autoremove() {
  sudo DEBIAN_FRONTEND=noninteractive apt-get -y autoremove || fail
}

# @description Add apt source and key
#
# @example
#    apt::add_key_and_source "https://dl.yarnpkg.com/debian/pubkey.gpg" "deb https://dl.yarnpkg.com/debian/ stable main" "yarn" | fail
#
# @arg $1 string key url
# @arg $2 string source string
# @arg $3 string source name for sources.list.d
apt::add_key_and_source() {
  local key_url="$1"
  local source_string="$2"
  local source_name="$3"

  local source_file="/etc/apt/sources.list.d/${source_name}.list"

  curl --fail --silent --show-error "${key_url}" | sudo apt-key add -
  test "${PIPESTATUS[*]}" = "0 0" || fail "Unable to get key from ${key_url} or import in into apt"

  echo "${source_string}" | sudo tee "${source_file}" >/dev/null || fail "Unable to write apt source into the ${source_file}"
}

# gnome-keyring and libsecret (for git and ssh)
apt::install_gnome_keyring_and_libsecret() {
  apt::install \
    gnome-keyring \
    libsecret-tools \
    libsecret-1-0 \
    libsecret-1-dev \
      || fail
}

apt::install_sopka_essential_dependencies() {
  apt::install curl git jq pass || softfail || return $?
}

apt::install_display_if_restart_required_dependencies() {
  apt::install debian-goodies || softfail || return $?
}
