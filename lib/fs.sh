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

fs::get_absolute_path() {
  local relative_path="$1"
  
  # get basename
  local path_basename; path_basename="$(basename "${relative_path}")" \
    || softfail "Unable to get a basename of '${relative_path}' ($?)" || return $?

  # get dirname that yet may result to relative path
  local unresolved_dir; unresolved_dir="$(dirname "${relative_path}")" \
    || softfail "Unable to get a dirname of '${relative_path}'" || return $?

  # get absolute path
  local resolved_dir; resolved_dir="$(cd "${unresolved_dir}" >/dev/null 2>&1 && pwd)" \
    || softfail "Unable to determine absolute path for '${unresolved_dir}'" || return $?

  echo "${resolved_dir}/${path_basename}"
}

fs::convert_msys_path_to_windows() {
  echo "$1" | sed "s/^\\/\\([[:alpha:]]\\)\\//\\1:\\//" | sed "s/\\//\\\\/g"
  test "${PIPESTATUS[*]}" = "0 0 0" || softfail || return $?
}  

fs::update_symlink() {
  local target_thing="$1"
  local link_name="$2"

  if [ -e "${link_name}" ] && [ ! -L "${link_name}" ]; then
    softfail "Unable to create/update symlink, some non-link file exists: ${link_name}"
    return $?
  fi

  ln --symbolic --force --no-dereference "${target_thing}" "${link_name}" || softfail || return $?
}

fs::with_secure_temp_dir_if_available() {
  if [[ "${OSTYPE}" =~ ^linux ]]; then
    linux::with_secure_temp_dir "$@"
  else
    "$@"
  fi
}

fs::wait_until_mounted() {
  local mountpoint="$1"

  if ! findmnt --mountpoint "${mountpoint}" >/dev/null; then
    echo "Filesystem is not mounted: '${mountpoint}'" >&2
    echo "Please connect the external media if the filesystem resides on it" >&2
    echo "Waiting for the filesystem to be available, press Control-C to interrupt" >&2
  fi

  while ! findmnt --mountpoint "${mountpoint}" >/dev/null; do
    sleep 0.1
  done
}
