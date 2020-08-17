#!/bin/bash

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

sublime::determine-config-path() {
  if [[ "$OSTYPE" =~ ^darwin ]]; then
    export SUBLIME_CONFIG_PATH="${HOME}/Library/Application Support/Sublime Text 3"
  elif [[ "$OSTYPE" =~ ^msys ]]; then
    export SUBLIME_CONFIG_PATH="${APPDATA}/Sublime Text 3"
  else
    export SUBLIME_CONFIG_PATH="${HOME}/.config/sublime-text-3"
  fi
}

sublime::apt::add-sublime-source() {
  curl --fail --silent --show-error https://download.sublimetext.com/sublimehq-pub.gpg | sudo apt-key add -
  test "${PIPESTATUS[*]}" = "0 0" || fail "Unable to curl https://download.sublimetext.com/sublimehq-pub.gpg | sudo apt-key add"

  echo "deb https://download.sublimetext.com/ apt/stable/" | sudo tee /etc/apt/sources.list.d/sublime-text.list || fail "Unable to write to /etc/apt/sources.list.d/sublime-text.list"
}

sublime::apt::install-sublime-merge() {
  sudo apt-get install -o Acquire::ForceIPv4=true -y sublime-merge || fail "Unable to apt-get install ($?)"
}

sublime::apt::install-sublime-text() {
  sudo apt-get install -o Acquire::ForceIPv4=true -y sublime-text || fail "Unable to apt-get install ($?)"
}

sublime::install-package-control() {
  local installedPackages="${SUBLIME_CONFIG_PATH}/Installed Packages"
  local packageControlPackage="${installedPackages}/Package Control.sublime-package"

  if [ ! -f "${packageControlPackage}" ]; then
    mkdir -p "${installedPackages}" || fail "Unable to create directory ${installedPackages} ($?)"

    curl --fail --silent --show-error "https://packagecontrol.io/Package%20Control.sublime-package" --output "${packageControlPackage}.tmp" || fail "Unable to download https://packagecontrol.io/Package%20Control.sublime-package ($?)"

    mv "${packageControlPackage}.tmp" "${packageControlPackage}" || fail "Unable to rename temp file to${packageControlPackage}"
  fi
}

sublime::install-config-file() {
  sublime::determine-config-path || fail
  config::install "$1/$2" "${SUBLIME_CONFIG_PATH}/Packages/User/$2" || fail "Unable to install $1 ($?)"
}

sublime::merge-config-file() {
  sublime::determine-config-path || fail
  config::merge "$1/$2" "${SUBLIME_CONFIG_PATH}/Packages/User/$2" || fail "Unable to merge $1 ($?)"
}
