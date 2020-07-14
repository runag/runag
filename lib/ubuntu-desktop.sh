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

ubuntu::desktop::setup-imwhell() {
  local repetitions="2"
  local outputFile="${HOME}/.imwheelrc"
  tee "${outputFile}" <<SHELL || fail "Unable to write file: ${outputFile} ($?)"
".*"
None,      Up,   Button4, ${repetitions}
None,      Down, Button5, ${repetitions}
Control_L, Up,   Control_L|Button4
Control_L, Down, Control_L|Button5
Shift_L,   Up,   Shift_L|Button4
Shift_L,   Down, Shift_L|Button5
SHELL

  if [ ! -d "${HOME}/.config/autostart" ]; then
    mkdir -p "${HOME}/.config/autostart" || fail
  fi

  local outputFile="${HOME}/.config/autostart/imwheel.desktop"
  tee "${outputFile}" <<SHELL || fail "Unable to write file: ${outputFile} ($?)"
[Desktop Entry]
Type=Application
Exec=/usr/bin/imwheel
Hidden=false
NoDisplay=false
X-GNOME-Autostart-enabled=true
OnlyShowIn=GNOME;XFCE;
Name[en_US]=IMWheel
Name=IMWheel
Comment[en_US]=Custom scroll speed
Comment=Custom scroll speed
SHELL

  /usr/bin/imwheel --kill
}

ubuntu::desktop::hide-folder() {
  local hiddenFile="${HOME}/.hidden"

  touch "${hiddenFile}" || fail

  if ! grep --quiet "^$1\$" "${hiddenFile}"; then
    echo "$1" >>"${hiddenFile}" || fail
  fi
}

ubuntu::desktop::moz-enable-wayland() {
  local pamFile="${HOME}/.pam_environment"
  touch "${pamFile}" || fail

  if ! grep --quiet "^MOZ_ENABLE_WAYLAND" "${pamFile}"; then
    echo "MOZ_ENABLE_WAYLAND=1" >>"${pamFile}" || fail
  fi
}

ubuntu::desktop::install-corecoding-vitals-gnome-shell-extension() {
  local extensionsDir="${HOME}/.local/share/gnome-shell/extensions"
  local extensionUuid="Vitals@CoreCoding.com"

  apt::install gir1.2-gtop-2.0 lm-sensors || fail

  mkdir -p "${extensionsDir}" || fail

  git::clone-or-pull "https://github.com/corecoding/Vitals" "${extensionsDir}/${extensionUuid}" || fail

  gnome-extensions enable "${extensionUuid}" || fail
}
