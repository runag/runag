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

# @description Perform apt update
apt::update() {
  sudo DEBIAN_FRONTEND=noninteractive apt-get update || fail
}

# @description Perform apt dist-upgrade
apt::dist_upgrade() {
  # TODO: Check if this Dpkg::Options are good defaults
  sudo DEBIAN_FRONTEND=noninteractive apt-get -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" -y dist-upgrade || fail
}

apt::dist_upgrade_unless_ci() {
  if [ "${CI:-}" != "true" ]; then
    apt::dist_upgrade || softfail || return $?
  fi
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
#   apt::add_key_and_source "https://packages.microsoft.com/keys/microsoft.asc" "packages.microsoft" "https://packages.microsoft.com/repos/code stable main" "vscode" || softfail || return $?
#
# @arg $1 string key url
apt::add_key_and_source() {
  local key_url="$1"
  local key_name="$2"
  local source_string="$3"
  local source_filename="$4"

  apt::install curl gpg apt-transport-https || softfail || return $?

  curl --fail --silent --show-error "${key_url}" | gpg --dearmor | file::sudo_write "/etc/apt/keyrings/${key_name}.gpg" 0644 root root
  test "${PIPESTATUS[*]}" = "0 0 0" || fail "Unable to get key from ${key_url} or to save it"

  <<<"deb [arch=amd64,arm64,armhf signed-by=/etc/apt/keyrings/${key_name}.gpg] ${source_string}" file::sudo_write "/etc/apt/sources.list.d/${source_filename}.list" || softfail || return $?

  apt::update || softfail || return $?
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
