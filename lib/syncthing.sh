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

syncthing::install::macos() {
  brew install syncthing || softfail || return $?
  brew services start syncthing || softfail || return $?
}

syncthing::install() (
  # shellcheck disable=SC1091
  . /etc/os-release || softfail || return $?

  if [ "${ID:-}" = debian ] || [ "${ID_LIKE:-}" = debian ]; then
    apt::add_source_with_key "syncthing" \
      "https://apt.syncthing.net/ syncthing stable" \
      "https://syncthing.net/release-key.txt" || softfail "Unable to add syncthing apt source" || return $?

    apt::install syncthing || softfail || return $?
        
  elif [ "${ID:-}" = arch ]; then
    sudo pacman --sync --needed --noconfirm syncthing || softfail || return $?
  fi

  systemctl --user --now enable syncthing.service || softfail || return $?

#   # https://wiki.archlinux.org/title/Desktop_entries#Hide_desktop_entries
#   file::write "${HOME}/.local/share/applications/syncthing-start.desktop" <<SHELL || fail
# [Desktop Entry]
# Type=Application
# NoDisplay=true
# Hidden=true
# SHELL
#
#   sudo update-desktop-database || fail
)

syncthing::open() {
  xdg-open "http://127.0.0.1:8384" || softfail || return $?
}
