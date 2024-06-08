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

# --mode
# --owner
# --group
# --sudo
# --keep-permissions
dir::should_exists() {
  local dir_mode
  local dir_owner
  local dir_group
  local perhaps_sudo
  local keep_permissions=false

  while [ "$#" -gt 0 ]; do
    case "$1" in
      -m|--mode)
        dir_mode="$2"
        shift; shift
        ;;
      -o|--owner)
        dir_owner="$2"
        shift; shift
        ;;
      -g|--group)
        dir_group="$2"
        shift; shift
        ;;
      -s|--sudo)
        perhaps_sudo=true
        shift
        ;;
      -k|--keep-permissions)
        keep_permissions=true
        shift
        ;;
      -*)
        softfail "Unknown argument: $1" || return $?
        ;;
      *)
        break
        ;;
    esac
  done

  local dir_path="$1"

  if ${perhaps_sudo:+"sudo"} mkdir ${dir_mode:+-m "${dir_mode}"} "${dir_path}" 2>/dev/null; then
    if [ -n "${dir_owner:-}" ]; then
      ${perhaps_sudo:+"sudo"} chown "${dir_owner}${dir_group:+":${dir_group}"}" "${dir_path}" || softfail || return $?
    fi
  else
    if ${perhaps_sudo:+"sudo"} test ! -d "${dir_path}"; then
      softfail "Unable to create directory" || return $?
    fi

    if [ "${keep_permissions}" = false ]; then
      if [ -n "${dir_mode:-}" ]; then
        ${perhaps_sudo:+"sudo"} chmod "${dir_mode}" "${dir_path}" || softfail || return $?
      fi

      if [ -n "${dir_owner:-}" ]; then
        ${perhaps_sudo:+"sudo"} chown "${dir_owner}${dir_group:+":${dir_group}"}" "${dir_path}" || softfail || return $?
      fi
    fi
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
