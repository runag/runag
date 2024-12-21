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

# ### `relative::realpath`
#
# This function returns the absolute path of the specified file or directory, relative to the caller's directory.
# It changes the working directory to the caller's directory before invoking `realpath` to resolve the full path.
#
# #### Usage:
# 
# relative::realpath args...
#
# #### Example:
# 
# relative::realpath --canonicalize-existing mydir
#
relative::realpath() (
  # Get the caller's directory.
  local caller_dir; caller_dir="$(dirname "${BASH_SOURCE[1]}")" || softfail "Failed to get caller directory" || return $?

  # Change the current directory to the caller's directory.
  cd "${caller_dir}" || softfail "Failed to change directory to ${caller_dir}" || return $?

  # Return the absolute path of the provided argument(s).
  realpath "$@"
)

# ### `relative::cd`
#
# This function changes the current working directory to a specified path, relative to the caller's directory.
#
# #### Usage:
# 
# relative::cd path
#
# #### Example:
# 
# relative::cd mydir
#
relative::cd() {
  # Get the caller's directory.
  local caller_dir; caller_dir="$(dirname "${BASH_SOURCE[1]}")" || softfail "Failed to get caller directory" || return $?

  # Change the current directory to the specified path.
  cd "${caller_dir}/$1" || softfail "Failed to change directory to ${caller_dir}/$1" || return $?
}

# ### `relative::source`
#
# This function sources a script file or files from the caller's directory. 
#
# If the `--recursive` or `-r` option is provided, it will source all `.sh` files in the specified directory recursively.
#
# #### Usage:
#
# relative::source path [args...]
# relative::source --recursive path [args...]
#
# - `--recursive` or `-r`: If specified, the function will recursively source all `.sh` files in the given directory.
# - `path`: The path to the script or directory to source, specified relative to the caller's directory.
# - `args`: Optional arguments to pass to the sourced script(s).
#
# #### Example:
#
# relative::source myscript.sh
# relative::source --recursive scripts
#
relative::source() {
  # Get the caller's directory.
  local caller_dir; caller_dir="$(dirname "${BASH_SOURCE[1]}")" || softfail "Failed to get caller directory" || return $?

  # Flag to indicate recursive sourcing.
  recursive_flag=false

  # Parse the command-line arguments.
  while [ "$#" -gt 0 ]; do
    case "$1" in
      -r|--recursive)
        # Set the flag to true for recursive sourcing.
        recursive_flag=true
        shift
        ;;
      -*)
        # Handle unknown arguments.
        softfail "Unknown argument: $1" || return $?
        ;;
      *)
        break
        ;;
    esac
  done

  # If recursive flag is set, source files recursively.
  if [ "${recursive_flag}" = true ]; then
    relative::source::walk_directory "${caller_dir}/$1" "${@:2}" || softfail "Unable to load recursively from: ${caller_dir}/$1" || return $?
  else
    # Source the specified file.
    . "${caller_dir}/$1" "${@:2}" || softfail "Unable to load: ${caller_dir}/$1" || return $?
  fi
}

# ### `relative::source::walk_directory`
#
# This function recursively walks through a directory and sources all `.sh` files.
# It sources files in the current directory first and then iterates through any subdirectories.
#
# #### Usage:
#
# relative::source::walk_directory [directory] [args...]
#
# #### Example:
#
# relative::source::walk_directory mydir
#
relative::source::walk_directory() {
  local dir_list=()  # List of directories to process
  local item dir_item

  # Iterate over all items in the directory.
  for item in "$1/"*; do
    # If the item is a directory, add it to the directory list.
    if [ -d "${item}" ]; then
      dir_list+=("${item}")
    # If the item is a file and has a `.sh` extension, source it.
    elif [ -f "${item}" ] && [[ "${item}" =~ \.sh$ ]]; then
      . "${item}" "${@:2}" || softfail "Unable to load: ${item}" || return $?
    fi
  done

  # Recursively walk through subdirectories.
  for dir_item in "${dir_list[@]}"; do
    relative::source::walk_directory "${dir_item}" "${@:2}" || softfail "Unable to load from directory: ${dir_item}" || return $?
  done
}
