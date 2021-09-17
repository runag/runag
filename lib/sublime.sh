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

sublime::get-config-path() {
  local configPath

  if [[ "${OSTYPE}" =~ ^darwin ]]; then
    configPath="${HOME}/Library/Application Support/Sublime Text 3"

  elif [[ "${OSTYPE}" =~ ^msys ]]; then
    configPath="${APPDATA}/Sublime Text 3"

  else
    dir::make-if-not-exists "${HOME}/.config" 755 || fail
    configPath="${HOME}/.config/sublime-text-3"
  fi

  dir::make-if-not-exists "${configPath}" 700 || fail
  echo "${configPath}"
}

sublime::install-package-control() {
  local configPath; configPath="$(sublime::get-config-path)" || fail
  local installedPackages="${configPath}/Installed Packages"
  local packageControlPackage="${installedPackages}/Package Control.sublime-package"

  if [ ! -f "${packageControlPackage}" ]; then
    dir::make-if-not-exists "${installedPackages}" 700 || fail

    local url="https://packagecontrol.io/Package%20Control.sublime-package"

    curl --fail --silent --show-error "${url}" --output "${packageControlPackage}.download-tmp" || fail "Unable to download ${url} ($?)"

    mv "${packageControlPackage}.download-tmp" "${packageControlPackage}" || fail
  fi
}

sublime::install-config-file() {
  local srcPath="$1"

  local fileName; fileName="$(basename "${srcPath}")" || fail
  local configPath; configPath="$(sublime::get-config-path)" || fail

  dir::make-if-not-exists "${configPath}/Packages" 700 || fail
  dir::make-if-not-exists "${configPath}/Packages/User" 700 || fail

  config::install "${srcPath}" "${configPath}/Packages/User/${fileName}" || fail
}

sublime::merge-config-file() {
  local srcPath="$1"
  
  local fileName; fileName="$(basename "${srcPath}")" || fail
  local configPath; configPath="$(sublime::get-config-path)" || fail

  config::merge "${srcPath}" "${configPath}/Packages/User/${fileName}" || fail
}
