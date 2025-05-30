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

firefox::enable_wayland() {
  shellfile::write "profile/firefox-enable-wayland" <<SHELL || softfail || return $?
export MOZ_ENABLE_WAYLAND=1
SHELL
}

firefox::set_pref() {
  local name="$1"
  local value="$2"
  
  local prefs_line="user_pref(\"${name}\", ${value});"
  
  local profile_dir; for profile_dir in "${HOME}/.mozilla/firefox"/*.default-release; do
    if [ -d "${profile_dir}" ]; then
      local prefs_file="${profile_dir}/prefs.js"
      if ! grep -qFx "${prefs_line}" "${prefs_file}"; then
        echo "${prefs_line}" >>"${prefs_file}" || softfail || return $?
      fi
    fi
  done
}
