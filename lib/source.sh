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

source::related_to_file() {
  local self_dir; self_dir="$(dirname "$1")" || softfail "Unable to get dirname of $1" || return $?

  . "${self_dir}/$2" || softfail "Unable to load: ${self_dir}/$2" || return $?
}

source::recursive_related_to_file() {
  local file_name="$1"
  local start_from="$2"

  local file_dir; file_dir="$(dirname "${file_name}")" || softfail "Unable to get dirname of ${file_name}" || return $?

  source::recursive "${file_dir}/${start_from}" || softfail || return $?
}

source::recursive() {
  local directory_path="$1"

  # we require files first in order for the runagfile_menu items to be sorted in a top-down manner

  local item_path; for item_path in "${directory_path}"/*; do
    if [ -f "${item_path}" ] && [[ "${item_path}" =~ \.sh$ ]]; then
      . "${item_path}" || softfail "Unable to load: ${file_path}" || return $?
    fi
  done

  local item_path; for item_path in "${directory_path}"/*; do
    if [ -d "${item_path}" ]; then
      source::recursive "${item_path}" || softfail || return $?
    fi
  done
}
