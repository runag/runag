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

runagfile::add_from_list() {
  local line; while IFS="" read -r line; do
    if [ -n "${line}" ]; then
      echo "Adding rùnagfile from ${line}..."
      runagfile::add "${line}" || softfail "Unable to add rùnagfile ${line}" || return $?
    fi
  done || softfail "Unable to add rùnagfiles from list" || return $?
}

runagfile::add() {
  local user_name; user_name="$(<<<"$1" cut -d "/" -f 1)" || softfail || return $?
  local repo_name; repo_name="$(<<<"$1" cut -d "/" -f 2)" || softfail || return $?
  git::place_up_to_date_clone "https://github.com/${user_name}/${repo_name}.git" "${HOME}/.runag/runagfiles/${repo_name}-${user_name}-github" || softfail || return $?
}

runagfile::each() {
  local runagfile_dir; for runagfile_dir in "${HOME}/.runag/runagfiles"/*; do
    if [ -d "${runagfile_dir}" ]; then
      ( cd "${runagfile_dir}" && "$@" ) || softfail || return $?
    fi
  done
}

# Find and load rùnagfile.
#
# Possible locations are:
#
# in current working directory
# ./runagfile.sh
# ./runagfile/runagfile.sh
#
# in home directory
# ~/.runagfile.sh
# ~/.runagfile/runagfile.sh
#
# inside of the collection of rùnagfiles that were added to a rùnag installation
# ~/.runag/runagfiles/*/runagfile.sh
# ~/.runag/runagfiles/*/runagfile/runagfile.sh
#
runagfile::load() {
  local working_directory_only=false

  while [ "$#" -gt 0 ]; do
    case "$1" in
      -w|--working-directory-only)
        working_directory_only=true
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

  if [ -f "./runagfile.sh" ]; then
    . "./runagfile.sh"
    softfail --unless-good --exit-status $? "Unable to load './runagfile.sh' ($?)"
    return $?

  elif [ -f "./runagfile/runagfile.sh" ]; then
    . "./runagfile/runagfile.sh"
    softfail --unless-good --exit-status $? "Unable to load './runagfile/runagfile.sh' ($?)"
    return $?

  elif [ "${working_directory_only}" = false ] && [ -n "${HOME:-}" ]; then

    if [ -f "${HOME}/.runagfile.sh" ]; then
      . "${HOME}/.runagfile.sh"
      softfail --unless-good --exit-status $? "Unable to load '${HOME}/.runagfile.sh' ($?)" || return $?

    elif [ -f "${HOME}/.runagfile/runagfile.sh" ]; then
      . "${HOME}/.runagfile/runagfile.sh"
      softfail --unless-good --exit-status $? "Unable to load '${HOME}/.runagfile/runagfile.sh' ($?)" || return $?
    fi

    local dir_path; for dir_path in "${HOME}/.runag/runagfiles/"*; do
      if [ -d "${dir_path}" ]; then
        if [ -f "${dir_path}/runagfile.sh" ]; then
          . "${dir_path}/runagfile.sh"
          softfail --unless-good --exit-status $? "Unable to load '${dir_path}/runagfile.sh' ($?)" || return $?

        elif [ -f "${dir_path}/runagfile/runagfile.sh" ]; then
          . "${dir_path}/runagfile/runagfile.sh"
          softfail --unless-good --exit-status $? "Unable to load '${dir_path}/runagfile/runagfile.sh' ($?)" || return $?
        fi
      fi
    done

  fi
}
