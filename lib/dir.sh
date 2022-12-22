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

dir::make_if_not_exists() {
  local dir_path="$1"
  local mode="${2:-}"
  local owner="${3:-}"
  local group="${4:-}"

  if mkdir ${mode:+-m "${mode}"} "${dir_path}" 2>/dev/null; then
    if [ -n "${owner}" ]; then
      chown "${owner}${group:+".${group}"}" "${dir_path}" || softfail || return $?
    fi
  else
    test -d "${dir_path}" || softfail "Unable to create directory, maybe there is a file here already: ${dir_path}" || return $?
  fi
}

dir::make_if_not_exists_and_set_permissions() {
  local dir_path="$1"
  local mode="${2:-}"
  local owner="${3:-}"
  local group="${4:-}"

  if ! mkdir ${mode:+-m "${mode}"} "${dir_path}" 2>/dev/null; then
    test -d "${dir_path}" || softfail "Unable to create directory, maybe there is a file here already: ${dir_path}" || return $?
    chmod "${mode}" "${dir_path}" || softfail || return $?
  fi

  if [ -n "${owner}" ]; then
    chown "${owner}${group:+".${group}"}" "${dir_path}" || softfail || return $?
  fi
}

dir::sudo_make_if_not_exists() {
  local dir_path="$1"
  local mode="${2:-}"
  local owner="${3:-}"
  local group="${4:-}"

  if sudo mkdir ${mode:+-m "${mode}"} "${dir_path}" 2>/dev/null; then
    if [ -n "${owner}" ]; then
      sudo chown "${owner}${group:+".${group}"}" "${dir_path}" || softfail || return $?
    fi
  else
    test -d "${dir_path}" || softfail "Unable to create directory, maybe there is a file here already: ${dir_path}" || return $?
  fi
}

dir::sudo_make_if_not_exists_and_set_permissions() {
  local dir_path="$1"
  local mode="${2:-}"
  local owner="${3:-}"
  local group="${4:-}"

  if ! sudo mkdir ${mode:+-m "${mode}"} "${dir_path}" 2>/dev/null; then
    test -d "${dir_path}" || softfail "Unable to create directory, maybe there is a file here already: ${dir_path}" || return $?
    sudo chmod "${mode}" "${dir_path}" || softfail || return $?
  fi

  if [ -n "${owner}" ]; then
    sudo chown "${owner}${group:+".${group}"}" "${dir_path}" || softfail || return $?
  fi
}

dir::remove_if_exists_and_empty() {
  local dir_path="$1"
  rmdir "${dir_path}" 2>/dev/null || true
}

dir::default_mode() {
  local umask_value; umask_value="$(umask)" || softfail || return $?
  printf "%o" "$(( 0777 ^ "${umask_value}" ))" || softfail || return $?
}

dir::default_mode_with_remote_umask() {
  printf "%o" "$(( 0777 ^ "0${REMOTE_UMASK}" ))" || softfail || return $?
}
