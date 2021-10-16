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

sublime-text::install::apt() {
  apt::add-key-and-source "https://download.sublimetext.com/sublimehq-pub.gpg" "deb https://download.sublimetext.com/ apt/stable/" "sublime-text" || softfail || return
  apt::update || softfail || return
  apt::install sublime-text || softfail || return
}

sublime-text::get-config-path() {
  local configPath

  if [[ "${OSTYPE}" =~ ^darwin ]]; then
    configPath="${HOME}/Library/Application Support/Sublime Text 3"

  elif [[ "${OSTYPE}" =~ ^msys ]]; then
    configPath="${APPDATA}/Sublime Text 3"

  else
    dir::make-if-not-exists "${HOME}/.config" 755 || softfail || return
    configPath="${HOME}/.config/sublime-text-3"
  fi

  dir::make-if-not-exists "${configPath}" 700 || softfail || return
  echo "${configPath}"
}

sublime-text::install-package-control() {
  local configPath; configPath="$(sublime-text::get-config-path)" || softfail || return
  local installedPackages="${configPath}/Installed Packages"
  local packageControlPackage="${installedPackages}/Package Control.sublime-package"

  if [ ! -f "${packageControlPackage}" ]; then
    dir::make-if-not-exists "${installedPackages}" 700 || softfail || return

    local url="https://packagecontrol.io/Package%20Control.sublime-package"

    curl --fail --silent --show-error "${url}" --output "${packageControlPackage}.download-tmp" || softfail "Unable to download ${url} ($?)" || return

    mv "${packageControlPackage}.download-tmp" "${packageControlPackage}" || softfail || return
  fi
}

sublime-text::install-config-file() {
  local srcPath="$1"

  local fileName; fileName="$(basename "${srcPath}")" || softfail || return
  local configPath; configPath="$(sublime-text::get-config-path)" || softfail || return

  dir::make-if-not-exists "${configPath}/Packages" 700 || softfail || return
  dir::make-if-not-exists "${configPath}/Packages/User" 700 || softfail || return

  config::install "${srcPath}" "${configPath}/Packages/User/${fileName}" || softfail || return
}

sublime-text::merge-config-file() {
  local srcPath="$1"
  
  local fileName; fileName="$(basename "${srcPath}")" || softfail || return
  local configPath; configPath="$(sublime-text::get-config-path)" || softfail || return

  config::merge "${srcPath}" "${configPath}/Packages/User/${fileName}" || softfail || return
}
