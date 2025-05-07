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

# ## `runag::load_runag_library`
#
# Loads the core Runag library files required for script initialization.
#
# ### Usage
#
# runag::load_runag_library <library-directory>
#
# Arguments:
#   <library-directory>   Relative path to the directory containing Runag .sh library files
#
runag::load_runag_library() {
  local self_path="${BASH_SOURCE[0]}"
  local self_dir

  # Resolve the full path if the script is a symbolic link
  if [ -L "${self_path}" ]; then
    self_path="$(readlink -f "${self_path}")" || {
      echo "Could not resolve symbolic link for ${BASH_SOURCE[0]} (exit code $?)." >&2
      return 1
    }
  fi

  # Determine the directory in which the script resides
  self_dir="$(dirname "${self_path}")" || {
    echo "Could not determine the directory of ${self_path} (exit code $?)." >&2
    return 1
  }

  # Construct the path to the library directory
  local lib_dir="${self_dir}/$1"

  # Verify that the library directory exists
  test -d "${lib_dir}" || {
    echo "The specified library directory '${lib_dir}' was not found." >&2
    return 1
  }

  # Load each .sh file in the library directory
  local file_path; for file_path in "${lib_dir}"/*.sh; do
    if [ -f "${file_path}" ]; then
      # shellcheck disable=SC1090
      source "${file_path}" || {
        echo "Failed to load library file: ${file_path} (exit code $?)." >&2
        return 1
      }
    fi
  done
}

# Load all required Runag library files from the '../lib' directory
runag::load_runag_library "lib" || {
  echo "Could not initialize the Runag library (exit code $?)." >&2
  if [ "${BASH_SOURCE[0]}" != "$0" ]; then
    return 1 # Return if this script is being sourced
  else
    exit 1 # Exit if this script is being run directly
  fi
}

# Remove the function to avoid leaving it in the global namespace
unset -f runag::load_runag_library
