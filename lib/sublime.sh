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

sublime::apt::install-merge-and-text() {
  apt::add-key-and-source "https://download.sublimetext.com/sublimehq-pub.gpg" "deb https://download.sublimetext.com/ apt/stable/" "sublime-text" || fail
  apt::update || fail
  apt::install sublime-merge || fail
  apt::install sublime-text || fail
}

sublime::config-path() {
  if [[ "${OSTYPE}" =~ ^darwin ]]; then
    echo "${HOME}/Library/Application Support/Sublime Text 3"
  elif [[ "${OSTYPE}" =~ ^msys ]]; then
    echo "${APPDATA}/Sublime Text 3"
  else
    echo "${HOME}/.config/sublime-text-3"
  fi
}

sublime::install-package-control() {
  local configPath; configPath="$(sublime::config-path)" || fail
  local installedPackages="${configPath}/Installed Packages"
  local packageControlPackage="${installedPackages}/Package Control.sublime-package"

  if [ ! -f "${packageControlPackage}" ]; then
    mkdir -p "${installedPackages}" || fail "Unable to create directory ${installedPackages} ($?)"

    curl --fail --silent --show-error "https://packagecontrol.io/Package%20Control.sublime-package" --output "${packageControlPackage}.tmp" || fail "Unable to download https://packagecontrol.io/Package%20Control.sublime-package ($?)"

    mv "${packageControlPackage}.tmp" "${packageControlPackage}" || fail "Unable to rename temp file to${packageControlPackage}"
  fi
}

sublime::install-config-file() {
  local configPath; configPath="$(sublime::config-path)" || fail
  config::install "$1/$2" "${configPath}/Packages/User/$2" || fail "Unable to install $1 ($?)"
}

sublime::merge-config-file() {
  local configPath; configPath="$(sublime::config-path)" || fail
  config::merge "$1/$2" "${configPath}/Packages/User/$2" || fail "Unable to merge $1 ($?)"
}
