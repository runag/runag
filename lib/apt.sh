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

# @description Perform apt update
apt::update() {
  task::run_with_title "apt-get update" sudo DEBIAN_FRONTEND=noninteractive apt-get update || softfail || return $?
}

# @description Perform apt dist-upgrade
apt::dist_upgrade() {
  # TODO: Check if this Dpkg::Options are good defaults
  task::run_with_title "apt-get dist-upgrade" sudo DEBIAN_FRONTEND=noninteractive apt-get -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" -y dist-upgrade || softfail || return $?
}

apt::dist_upgrade_unless_ci() {
  if [ "${CI:-}" != "true" ]; then
    apt::dist_upgrade || softfail || return $?
  fi
}

# @description Install package
apt::install() {
  task::run_with_title "apt-get install $*" sudo DEBIAN_FRONTEND=noninteractive apt-get -y install "$@" || softfail || return $?
}

apt::remove() {
  task::run_with_title "apt-get remove" sudo DEBIAN_FRONTEND=noninteractive apt-get -y remove "$@" || softfail || return $?
}

# @description Perform apt autoremove
apt::autoremove() {
  task::run_with_title "apt-get autoremove" sudo DEBIAN_FRONTEND=noninteractive apt-get -y autoremove || softfail || return $?
}

# @description Add apt source and key
#
# @example
#   apt::add_source_with_key "vscode" \
#     "https://packages.microsoft.com/repos/code stable main" \
#     "https://packages.microsoft.com/keys/microsoft.asc" || softfail || return $?
#
apt::add_source_with_key() {
  local source_name="$1"
  local source_string="$2"
  local key_url="$3"

  curl --fail --silent --show-error "${key_url}" | gpg --dearmor | file::sudo_write "/etc/apt/keyrings/${source_name}.gpg" 0644 root root
  test "${PIPESTATUS[*]}" = "0 0 0" || softfail "Unable to get key or to save it: ${key_url} " || return $?

  <<<"deb [arch=amd64,arm64,armhf signed-by=/etc/apt/keyrings/${source_name}.gpg] ${source_string}" file::sudo_write "/etc/apt/sources.list.d/${source_name}.list" || softfail || return $?

  apt::update || softfail || return $?
}
