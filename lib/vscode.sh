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

vscode::snap::install() {
  sudo snap install code --classic || fail "Unable to snap install ($?)"
}

vscode::get-config-path() {
  local configPath

  if [[ "${OSTYPE}" =~ ^darwin ]]; then
    configPath="${HOME}/Library/Application Support/Code"

  elif [[ "${OSTYPE}" =~ ^msys ]]; then
    configPath="${APPDATA}/Code"

  else
    dir::make-if-not-exists "${HOME}/.config" 755 || fail
    configPath="${HOME}/.config/Code"
  fi

  dir::make-if-not-exists "${configPath}" 700 || fail
  echo "${configPath}"
}

vscode::list-extensions-to-temp-file() {
  local tmpFile; tmpFile="$(mktemp)" || fail "Unable to create temp file"

  code --list-extensions | sort > "${tmpFile}"

  test "${PIPESTATUS[*]}" = "0 0" || fail "Unable to list extensions"
  echo "${tmpFile}"
}

vscode::install-extensions() {
  local extensionsList="$1"

  if [ -f "${extensionsList}" ]; then
    local installedExtensionsList; installedExtensionsList="$(vscode::list-extensions-to-temp-file)" || fail "Unable get extensions list"

    if ! diff --strip-trailing-cr "${extensionsList}" "${installedExtensionsList}" >/dev/null 2>&1; then
      local extension

      if [[ "${OSTYPE}" =~ ^msys ]]; then
        local ifs_value=$'\r'
      else
        export ifs_value=""
      fi

      # TODO: how to do correct error handling here (cat | while)?
      while IFS="${ifs_value}" read -r extension; do
        if [ -n "${extension}" ]; then
          code --install-extension "${extension}" || fail "Unable to install vscode extension ${extension}"
        fi
      done <"${extensionsList}"
    fi

    rm "${installedExtensionsList}" || fail
  fi
}
