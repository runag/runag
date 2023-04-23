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

sublime_text::install::apt() {
  apt::add_source_with_key "sublimetext" \
    "https://download.sublimetext.com/ apt/stable/" \
    "https://download.sublimetext.com/sublimehq-pub.gpg" || softfail || return $?

  apt::install sublime-text || softfail || return $?
}

sublime_text::get_config_path() {
  local config_path

  if [[ "${OSTYPE}" =~ ^darwin ]]; then
    config_path="${HOME}/Library/Application Support/Sublime Text 3"

  elif [[ "${OSTYPE}" =~ ^msys ]]; then
    config_path="${APPDATA}/Sublime Text 3"

  else
    dir::make_if_not_exists "${HOME}/.config" 755 || softfail || return $?
    config_path="${HOME}/.config/sublime-text-3"
  fi

  dir::make_if_not_exists "${config_path}" 700 || softfail || return $?
  echo "${config_path}"
}

sublime_text::install_package_control() {
  local config_path; config_path="$(sublime_text::get_config_path)" || softfail || return $?
  local installed_packages="${config_path}/Installed Packages"
  local package_control_package="${installed_packages}/Package Control.sublime-package"

  if [ ! -f "${package_control_package}" ]; then
    dir::make_if_not_exists "${installed_packages}" 700 || softfail || return $?

    local url="https://packagecontrol.io/Package%20Control.sublime-package"

    curl --fail --silent --show-error "${url}" --output "${package_control_package}.download_temp" || softfail "Unable to download ${url} ($?)" || return $?

    mv "${package_control_package}.download_temp" "${package_control_package}" || softfail || return $?
  fi
}

sublime_text::install_config_file() {
  local src_path="$1"

  local file_name; file_name="$(basename "${src_path}")" || softfail || return $?
  local config_path; config_path="$(sublime_text::get_config_path)" || softfail || return $?

  dir::make_if_not_exists "${config_path}/Packages" 700 || softfail || return $?
  dir::make_if_not_exists "${config_path}/Packages/User" 700 || softfail || return $?

  config::install "${src_path}" "${config_path}/Packages/User/${file_name}" || softfail || return $?
}

sublime_text::merge_config_file() {
  local src_path="$1"
  
  local file_name; file_name="$(basename "${src_path}")" || softfail || return $?
  local config_path; config_path="$(sublime_text::get_config_path)" || softfail || return $?

  config::merge "${src_path}" "${config_path}/Packages/User/${file_name}" || softfail || return $?
}
