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

runag::load_lib() {
  # resolve symlink if needed
  if [ -L "${BASH_SOURCE[0]}" ]; then
    local index_path; index_path="$(readlink -f "${BASH_SOURCE[0]}")" || { echo "Unable to readlink '${BASH_SOURCE[0]}' ($?)" >&2; return 1; }
  else
    local index_path; index_path="${BASH_SOURCE[0]}"
  fi

  # get dirname that yet may result to relative path
  local unresolved_runag_dir; unresolved_runag_dir="$(dirname "${index_path}")" || { echo "Unable to get a dirname of '${index_path}' ($?)" >&2; return 1; }

  # get absolute path to dirname
  local runag_dir; runag_dir="$(cd "${unresolved_runag_dir}" >/dev/null 2>&1 && pwd)" || { echo "Unable to determine absolute path for '${unresolved_runag_dir}' ($?)" >&2; return 1; }

  # set RUNAG_BIN_PATH if needed
  if [ -z "${RUNAG_BIN_PATH:-}" ] && [ -f "${runag_dir}/bin/runag" ] && [ -x "${runag_dir}/bin/runag" ]; then
    export RUNAG_BIN_PATH="${runag_dir}/bin/runag"
  fi

  # load all lib/*.sh
  local file_path; for file_path in "${runag_dir}/lib"/*.sh; do
    if [ -f "${file_path}" ]; then
      . "${file_path}" || { echo "Unable to load '${file_path}' ($?)" >&2; return 1; }
    fi
  done
}

runag::load_lib || {
  echo "Unable to perform runag::load_lib' ($?)" >&2
  if [ "${BASH_SOURCE[0]}" != "$0" ]; then
    return 1 # use return if we are sourced
  else
    exit 1 # use exit if not
  fi
}
