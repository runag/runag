#!/usr/bin/env bash

#  Copyright 2012-2022 Stanislav Senotrusov <stan@senotrusov.com>
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

vscode::install::snap() {
  sudo snap install code --classic || softfail || return $?
}

vscode::install::apt() {
  apt::add_source_with_key "vscode" \
    "https://packages.microsoft.com/repos/code stable main" \
    "https://packages.microsoft.com/keys/microsoft.asc" || softfail || return $?

  apt::install code || softfail || return $?
}

vscode::get_config_path() {
  local config_path

  if [[ "${OSTYPE}" =~ ^darwin ]]; then
    config_path="${HOME}/Library/Application Support/Code"

  elif [[ "${OSTYPE}" =~ ^msys ]]; then
    config_path="${APPDATA}/Code"

  else
    dir::make_if_not_exists "${HOME}/.config" 755 || softfail || return $?
    config_path="${HOME}/.config/Code"
  fi

  dir::make_if_not_exists "${config_path}" 700 || softfail || return $?
  echo "${config_path}"
}

vscode::list_extensions_to_temp_file() {
  local temp_file; temp_file="$(mktemp)" || softfail "Unable to create temp file" || return $?

  code --list-extensions | sort > "${temp_file}"

  test "${PIPESTATUS[*]}" = "0 0" || softfail "Unable to list extensions" || return $?
  echo "${temp_file}"
}

vscode::install_extensions() {
  local extensions_list="$1"

  if [ -f "${extensions_list}" ]; then
    local installed_extensions_list; installed_extensions_list="$(vscode::list_extensions_to_temp_file)" || softfail "Unable get extensions list" || return $?

    if ! diff --strip-trailing-cr "${extensions_list}" "${installed_extensions_list}" >/dev/null 2>&1; then
      local extension

      if [[ "${OSTYPE}" =~ ^msys ]]; then
        local ifs_value=$'\r'
      else
        local ifs_value=""
      fi

      while IFS="${ifs_value}" read -r extension; do
        if [ -n "${extension}" ]; then
          code --install-extension "${extension}" || softfail "Unable to install vscode extension ${extension}" || return $?
        fi
      done <"${extensions_list}" || softfail "Unable to install vscode extensions" || return $?
    fi

    rm "${installed_extensions_list}" || softfail || return $?
  fi
}
