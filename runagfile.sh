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

runag::load_runag_library() {
  local self_path
  local lib_dir
  local file_path

  # resolve symlink if needed
  if [ -L "${BASH_SOURCE[0]}" ]; then
    self_path="$(readlink -f "${BASH_SOURCE[0]}")" || { echo "Unable to resolve symlink ${BASH_SOURCE[0]} ($?)" >&2; return 1; }
  else
    self_path="${BASH_SOURCE[0]}"
  fi

  # get dirname
  lib_dir="$(dirname "${self_path}")/$1" || { echo "Unable to get a dirname of ${self_path} ($?)" >&2; return 1; }

  # check if lib dir exists
  test -d "${lib_dir}" || { echo "Unable to find rùnag library directory ${lib_dir}" >&2; return 1; }

  # load library files
  for file_path in "${lib_dir}"/*.sh; do
    if [ -f "${file_path}" ]; then
      . "${file_path}" || { echo "Unable to load ${file_path} ($?)" >&2; return 1; }
    fi
  done
}

# Load rùnag library
runag::load_runag_library "lib" || {
  echo "Unable to load rùnag library ($?)" >&2
  if [ "${BASH_SOURCE[0]}" != "$0" ]; then
    return 1 # use return if we are sourced
  else
    exit 1 # use exit if not
  fi
}
