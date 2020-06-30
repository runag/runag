#!/usr/bin/env bash

#  Copyright 2012-2019 Stanislav Senotrusov <stan@senotrusov.com>
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

apt::update() {
  sudo apt-get -o Acquire::ForceIPv4=true update || fail "Unable to apt-get update ($?)"
}

apt::dist-upgrade() {
  sudo apt-get -o Acquire::ForceIPv4=true -y dist-upgrade || fail "Unable to apt-get dist-upgrade ($?)"
}

apt::install() {
  sudo apt-get install -o Acquire::ForceIPv4=true -y "$@" || fail "Unable to apt-get install $* ($?)"
}

apt::autoremove() {
  sudo apt-get -o Acquire::ForceIPv4=true -y autoremove || fail "Unable to apt-get autoremove ($?)"
}

apt::add-key-and-source() {
  local keyUrl="$1"
  local sourceString="$2"
  local sourceName="$3"
  local sourceFile="/etc/apt/sources.list.d/${sourceName}.list"

  curl --fail --silent --show-error "${keyUrl}" | sudo apt-key add -
  test "${PIPESTATUS[*]}" = "0 0" || fail "Unable to get key from ${keyUrl} or import in into apt"

  echo "${sourceString}" | sudo tee "${sourceFile}" || fail "Unable to write apt source into the ${sourceFile}"
}

apt::add-syncthing-source() {
  # following https://apt.syncthing.net/
  apt::add-key-and-source "https://syncthing.net/release-key.txt" "deb https://apt.syncthing.net/ syncthing stable" "syncthing" || fail "Unable to add syncthing apt source"
}

apt::add-obs-studio-source() {
  sudo add-apt-repository --yes ppa:obsproject/obs-studio || fail "Unable to add-apt-repository ppa:obsproject/obs-studio ($?)"
}

apt::perhaps-install-mbpfan() {
  if sudo dmidecode --string baseboard-version | grep --quiet "MacBookAir5\\,2"; then
    apt::install mbpfan || fail
  fi
}

apt::perhaps-install-open-vm-tools-desktop() {
  if sudo dmidecode -t system | grep --quiet "Product\\ Name\\:\\ VMware\\ Virtual\\ Platform"; then
    apt::install open-vm-tools open-vm-tools-desktop || fail
  fi
}

apt::install-dconf() {
  # dconf-tools for ubuntu earlier than 19.04
  if [ "$(apt-cache search --names-only dconf-tools | wc -l)" = "0" ]; then
    apt::install dconf-cli dconf-editor || fail
  else
    apt::install dconf-tools || fail
  fi
}

ubuntu::install-corecoding-vitals-gnome-shell-extension() {
  local extensionsDir="${HOME}/.local/share/gnome-shell/extensions"
  local extensionUuid="Vitals@CoreCoding.com"

  mkdir -p "${extensionsDir}" || fail

  git::clone-or-pull "https://github.com/corecoding/Vitals" "${extensionsDir}/${extensionUuid}" || fail

  gnome-extensions enable "${extensionUuid}" || fail
}
