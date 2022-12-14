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

fstab::add_mount_option() {
  local fstype="$1"
  local option="$2"

  local skip; skip="$(<<<"${option}" sed 's/^\([[:alnum:]]\+\).*/\1/')" || softfail || return $?

  sed "/^\(#\|[[:graph:]]\+[[:blank:]]\+[[:graph:]]\+[[:blank:]]\+${fstype}[[:blank:]]\+.*[[:blank:][:punct:]]${skip}\([[:blank:][:punct:]]\|$\)\)/!s/^\([[:graph:]]\+[[:blank:]]\+[[:graph:]]\+[[:blank:]]\+${fstype}[[:blank:]]\+defaults\)\([^[:alnum:]]\|$\)/\1,${option}\2/g;" \
    /etc/fstab | fstab::verify_and_write
    
  test "${PIPESTATUS[*]}" = "0 0" || softfail "Error adding mount option to /etc/fstab" || return $?
}

fstab::verify_and_write() {
  local temp_file; temp_file="$(mktemp)" || softfail || return $?

  cat >"${temp_file}" || softfail "Error writing to temp file: ${temp_file}" || return $?

  test -s "${temp_file}" || softfail "Error: fstab candidate should have size greater that zero: ${temp_file}" || return $?
  
  findmnt --verify --tab-file "${temp_file}" 2>&1 || softfail "Failed to verify fstab candidate: ${temp_file}" || return $?

  sudo install -o root -g root -m 0664 -C "${temp_file}" /etc/fstab || softfail "Failed to install new fstab: ${temp_file}" || return $?

  rm "${temp_file}" || softfail "Failed to remove temp file: ${temp_file}" || return $?
}
