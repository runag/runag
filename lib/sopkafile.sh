#!/usr/bin/env bash

#  Copyright 2012-2022 Stanislav Senotrusov <stan@senotrusov.com>
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
      echo "Adding runagfile from ${line}..."
      runagfile::add "${line}" || softfail "Unable to add runagfile ${line}" || return $?
    fi
  done || softfail "Unable to add runagfiles from list" || return $?
}

runagfile::add() {
  local user_name; user_name="$(<<<"$1" cut -d "/" -f 1)" || softfail || return $?
  local repo_name; repo_name="$(<<<"$1" cut -d "/" -f 2)" || softfail || return $?
  git::place_up_to_date_clone "https://github.com/${user_name}/${repo_name}.git" "${HOME}/.sopka/runagfiles/${repo_name}-${user_name}-github" || softfail || return $?
}

runagfile::update-everything-in-sopka() {
  local runagfile_dir; for runagfile_dir in "${HOME}"/.sopka/runagfiles/*; do
    if [ -d "${runagfile_dir}/.git" ]; then
      git -C "${runagfile_dir}" pull || softfail || return $?
    fi
  done
}

# Find and load runagfile.
#
# Possible locations are:
#
# ./runagfile
# ./runagfile/index.sh
#
# ~/.runagfile
# ~/.runagfile/index.sh
#
# ~/.sopka/runagfiles/*/index.sh
#
runagfile::load() {
  if [ -f "./runagfile.sh" ]; then
    . "./runagfile.sh"
    softfail_unless_good "Unable to load './runagfile.sh' ($?)" $?
    return $?

  elif [ -f "./runagfile/index.sh" ]; then
    . "./runagfile/index.sh"
    softfail_unless_good "Unable to load './runagfile/index.sh' ($?)" $?
    return $?

  elif [ -n "${HOME:-}" ] && [ -f "${HOME:-}/.runagfile.sh" ]; then
    . "${HOME:-}/.runagfile.sh"
    softfail_unless_good "Unable to load '${HOME:-}/.runagfile.sh' ($?)" $?
    return $?

  elif [ -n "${HOME:-}" ] && [ -f "${HOME:-}/.runagfile/index.sh" ]; then
    . "${HOME:-}/.runagfile/index.sh"
    softfail_unless_good "Unable to load '${HOME:-}/.runagfile/index.sh' ($?)" $?
    return $?

  else
    runagfile::load-everything-from-sopka
    softfail_unless_good "Unable to load runagfiles from .sopka ($?)" $? || return $?
  fi
}

runagfile::load-everything-from-sopka() {
  local file_path; for file_path in "${HOME}"/.sopka/runagfiles/*/index.sh; do
    if [ -f "${file_path}" ]; then
      . "${file_path}"
      softfail_unless_good "Unable to load '${file_path}' ($?)" $? || return $?
    fi
  done
}
