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

# ### `apt::update`
#
# This function updates the package list for the system using apt in a non-interactive manner.
#
# #### Usage
# 
# apt::update
#
apt::update() {
  sudo DEBIAN_FRONTEND=noninteractive apt-get update || softfail "Failed to update package list." || return $?
}

# ### `apt::upgrade`
#
# This function upgrades all installed packages to their latest versions.
# The upgrade process is non-interactive and uses default configuration options to handle package configuration conflicts.
#
# #### Usage
# 
# apt::upgrade
#
apt::upgrade() {
  # TODO: Verify if these Dpkg::Options are appropriate as default settings
  sudo DEBIAN_FRONTEND=noninteractive apt-get -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" -y upgrade || softfail "Failed to upgrade packages." || return $?
}

# ### `apt::install`
#
# This function installs specified packages using apt in a non-interactive manner.
#
# #### Usage
# 
# apt::install <package_name>...
#
apt::install() {
  sudo DEBIAN_FRONTEND=noninteractive apt-get -y install "$@" || softfail "Failed to install packages: $*" || return $?
}

# ### `apt::remove`
#
# This function removes specified packages using apt in a non-interactive manner.
#
# #### Usage
# 
# apt::remove <package_name>...
#
apt::remove() {
  sudo DEBIAN_FRONTEND=noninteractive apt-get -y remove "$@" || softfail "Failed to remove packages: $*" || return $?
}

# ### `apt::autoremove`
#
# This function removes unnecessary packages that were automatically installed and are no longer needed.
# It operates non-interactively.
#
# #### Usage
# 
# apt::autoremove
#
apt::autoremove() {
  sudo DEBIAN_FRONTEND=noninteractive apt-get -y autoremove || softfail "Failed to autoremove unnecessary packages." || return $?
}

# ### `apt::add_source_with_key`
#
# This function adds a new apt repository source along with its GPG key.
#
# #### Usage
# 
# apt::add_source_with_key <source_name> <source_url> <key_url>
#
# #### Example
#
#   apt::add_source_with_key "vscode" \
#     "https://packages.microsoft.com/repos/code stable main" \
#     "https://packages.microsoft.com/keys/microsoft.asc" || softfail "Failed to add source for vscode." || return $?
#
apt::add_source_with_key() {
  local source_name="$1"
  local source_string="$2"
  local key_url="$3"

  # Create a temporary file for storing the GPG key
  local temp_file; temp_file="$(mktemp)" || softfail "Failed to create temporary file for key." || return $?

  # Fetch the GPG key and store it in the temporary file
  curl --fail --silent --show-error "${key_url}" | gpg --dearmor >"${temp_file}"
  test "${PIPESTATUS[*]}" = "0 0" || softfail "Unable to get key or save it: ${key_url}" || return $?

  # Write the GPG key to the system's keyring
  file::write --sudo --mode 0644 --absorb "${temp_file}" "/etc/apt/keyrings/${source_name}.gpg" || softfail "Failed to write GPG key to keyring." || return $?

  # Add the source repository to the apt sources list
  <<<"deb [arch=amd64,arm64,armhf signed-by=/etc/apt/keyrings/${source_name}.gpg] ${source_string}" file::write --sudo --mode 0644 "/etc/apt/sources.list.d/${source_name}.list" || softfail "Failed to add repository source: ${source_name}" || return $?

  # Update apt to include the new source
  apt::update || softfail "Failed to update apt sources after adding new repository." || return $?
}
