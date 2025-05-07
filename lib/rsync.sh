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

rsync::sync() {
  local from_remote=false
  local to_remote=false
  local rsync_args=()

  while [ "$#" -gt 0 ]; do
    case "$1" in
      --from-remote)
        from_remote=true
        shift
        ;;
      --to-remote)
        to_remote=true
        shift
        ;;
      -*)
        rsync_args+=("$1")
        shift
        ;;
      *)
        break
        ;;
    esac
  done

  # TODO: account for multiple sources
  local sources_and_destination
  if [ "${from_remote}" = true ]; then
    sources_and_destination=("${REMOTE_HOST:+"${REMOTE_HOST}:"}$1" "$2")
  elif [ "${to_remote}" = true ]; then
    sources_and_destination=("$1" "${REMOTE_HOST:+"${REMOTE_HOST}:"}$2")
  else
    sources_and_destination=("$@")
  fi

  local Default_Rsync_Args; rsync::set_default_args || softfail || return $? # NOTE: strange transgressive variable
  local rsh_string; rsh_string="$(rsync::rsh_string)" || softfail || return $?

  rsync \
    --rsh "${rsh_string}" \
    "${Default_Rsync_Args[@]}" \
    "${rsync_args[@]}" \
    "${sources_and_destination[@]}" \
      || softfail || return $?
}

rsync::set_default_args() {
  Default_Rsync_Args=(--checksum --delete --links --perms --recursive --safe-links --times)
}

rsync::rsh_string() {
  local Ssh_Args=() # NOTE: strange transgressive variable
  
  ssh::call::set_ssh_args || softfail || return $?

  local rsh_string=""

  local ssh_arg; for ssh_arg in "${Ssh_Args[@]}"; do
    rsh_string+=" '$(<<<"${ssh_arg}" sed -E "s/'/''/")'" || softfail || return $?
  done

  echo "ssh ${rsh_string:1}" || softfail || return $?
}
