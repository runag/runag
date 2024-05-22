#!/usr/bin/env bash

#  Copyright 2012-2024 Rùnag project contributors
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
  local fstype

  while [ "$#" -gt 0 ]; do
    case "$1" in
      -f|--filesystem-type)
        fstype="$2"
        shift; shift
        ;;
      -*)
        softfail "Unknown argument: $1" || return $?
        ;;
      *)
        break
        ;;
    esac
  done

  local option="$1"

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

  file::write --sudo --mode 0664 --absorb "${temp_file}" /etc/fstab || softfail "Failed to install new fstab: ${temp_file}" || return $?
}
