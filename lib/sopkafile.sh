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

sopkafile::add_from_list() {
  local line; while IFS="" read -r line; do
    if [ -n "${line}" ]; then
      echo "Adding sopkafile from ${line}..."
      sopkafile::add "${line}" || softfail "Unable to add sopkafile ${line}" || return $?
    fi
  done || softfail "Unable to add sopkafiles from list" || return $?
}

sopkafile::add() {
  local user_name; user_name="$(<<<"$1" cut -d "/" -f 1)" || softfail || return $?
  local repo_name; repo_name="$(<<<"$1" cut -d "/" -f 2)" || softfail || return $?
  git::place_up_to_date_clone "https://github.com/${user_name}/${repo_name}.git" "${HOME}/.sopka/sopkafiles/${repo_name}-${user_name}-github" || softfail || return $?
}

sopkafile::update-everything-in-sopka() {
  local sopkafile_dir; for sopkafile_dir in "${HOME}"/.sopka/sopkafiles/*; do
    if [ -d "${sopkafile_dir}/.git" ]; then
      git -C "${sopkafile_dir}" pull || softfail || return $?
    fi
  done
}

# Find and load sopkafile.
#
# Possible locations are:
#
# ./sopkafile
# ./sopkafile/index.sh
#
# ~/.sopkafile
# ~/.sopkafile/index.sh
#
# ~/.sopka/sopkafiles/*/index.sh
#
sopkafile::load() {
  if [ -f "./sopkafile.sh" ]; then
    . "./sopkafile.sh"
    softfail_unless_good "Unable to load './sopkafile.sh' ($?)" $?
    return $?

  elif [ -f "./sopkafile/index.sh" ]; then
    . "./sopkafile/index.sh"
    softfail_unless_good "Unable to load './sopkafile/index.sh' ($?)" $?
    return $?

  elif [ -n "${HOME:-}" ] && [ -f "${HOME:-}/.sopkafile.sh" ]; then
    . "${HOME:-}/.sopkafile.sh"
    softfail_unless_good "Unable to load '${HOME:-}/.sopkafile.sh' ($?)" $?
    return $?

  elif [ -n "${HOME:-}" ] && [ -f "${HOME:-}/.sopkafile/index.sh" ]; then
    . "${HOME:-}/.sopkafile/index.sh"
    softfail_unless_good "Unable to load '${HOME:-}/.sopkafile/index.sh' ($?)" $?
    return $?

  else
    sopkafile::load-everything-from-sopka
    softfail_unless_good "Unable to load sopkafiles from .sopka ($?)" $? || return $?
  fi
}

sopkafile::load-everything-from-sopka() {
  local file_path; for file_path in "${HOME}"/.sopka/sopkafiles/*/index.sh; do
    if [ -f "${file_path}" ]; then
      . "${file_path}"
      softfail_unless_good "Unable to load '${file_path}' ($?)" $? || return $?
    fi
  done
}
