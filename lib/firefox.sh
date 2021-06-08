#!/usr/bin/env bash

#  Copyright 2012-2020 Stanislav Senotrusov <stan@senotrusov.com>
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

firefox::enable-wayland() {
  local pamFile="${HOME}/.pam_environment"

  touch "${pamFile}" || fail

  if ! grep --quiet "^MOZ_ENABLE_WAYLAND" "${pamFile}"; then
    echo "MOZ_ENABLE_WAYLAND=1" >>"${pamFile}" || fail
  fi
}

firefox::set-prefs() {
  local name="$1"
  local value="$2"
  local prefsLine="user_pref(\"${name}\", ${value});"
  local profileFolder
  local prefsFile

  for profileFolder in "${HOME}/.mozilla/firefox"/*.default-release; do
    if [ -d "$profileFolder" ]; then
      prefsFile="$profileFolder/prefs.js"
      if ! grep --quiet --fixed-strings --line-regexp "${prefsLine}" "${prefsFile}"; then
        echo "${prefsLine}" >>"${prefsFile}" || fail
      fi
    fi
  done
}
