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
# --for-me-only
dir::should_exists() (
  local dir_mode
  local dir_owner
  local dir_group
  local perhaps_sudo

  while [ "$#" -gt 0 ]; do
    case "$1" in
      -m|--mode)
        dir_mode="0$2"
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
      -f|--for-me-only)
        dir_mode=0700
        dir_owner="${USER}"
        dir_group="$(grep -E "^${USER}:" /etc/passwd | cut -d: -f4; test "${PIPESTATUS[*]}" = "0 0")" || softfail || return $?
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

  if [ -n "${dir_mode:-}" ]; then
    umask "$(printf "0%o" "$(( 0777 - "${dir_mode}" ))")" || softfail || return $?
  fi

  ${perhaps_sudo:+"sudo"} mkdir ${dir_mode:+-m "${dir_mode}"} -p "${dir_path}" || softfail || return $?

  if [ -n "${dir_mode:-}" ]; then
    ${perhaps_sudo:+"sudo"} chmod "${dir_mode}" "${dir_path}" || softfail || return $?
  fi

  if [ -n "${dir_owner:-}" ]; then
    ${perhaps_sudo:+"sudo"} chown "${dir_owner}${dir_group:+":${dir_group}"}" "${dir_path}" || softfail || return $?
    
  elif [ -n "${dir_group:-}" ]; then
    ${perhaps_sudo:+"sudo"} chgrp "${dir_group}" "${dir_path}" || softfail || return $?
  fi
)
