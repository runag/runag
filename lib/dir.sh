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

# ### `dir::ensure_exists`
#
# Ensures a directory exists with the specified properties. This function creates the directory if it doesn't exist 
# and applies the desired permissions, ownership, and group settings. Additionally, it provides options for running 
# the commands with elevated privileges or limiting access to the current user only.
#
# #### Usage
#
# `dir::ensure_exists` [OPTIONS] <path>
#
# - `-m|--mode <permissions>`: Set the directory's permissions in numeric form (e.g., 0755).
# - `-o|--owner <username>`: Set the directory's owner.
# - `-g|--group <groupname>`: Set the directory's group.
# - `-s|--sudo`: Use elevated privileges (sudo) for creating and modifying the directory.
# - `-u|--user-only`: Shortcut to set permissions to 0700 and ownership to the current user.
# - `<path>`: The path of the directory to ensure exists.
#
# #### Example
#
# ```bash
# dir::ensure_exists --mode 0755 --owner user --group admin /path/to/directory
# dir::ensure_exists --user-only /secure/directory
# dir::ensure_exists --sudo /path/to/dir
# ```
dir::ensure_exists() {
  local mode
  local owner
  local group
  local sudo

  # The following commented line is not currently in use but could be used to fetch the group of the current user.
  # group="$(awk -F: -v user="${USER}" '$1 == user {print $4}' /etc/passwd)"


  # Parse arguments to configure directory properties
  while [ "$#" -gt 0 ]; do
    case "$1" in
      -m|--mode)
        # Set directory permissions in numeric format (e.g., 0755)
        mode="0$2"
        shift 2
        ;;
      -o|--owner)
        # Set the directory's owner
        owner="$2"
        shift 2
        ;;
      -g|--group)
        # Set the directory's group ownership
        group="$2"
        shift 2
        ;;
      -s|--sudo)
        # Enable the use of sudo to run commands with elevated privileges
        sudo=true
        shift
        ;;
      -u|--user-only)
        # Default permissions (0700) and ownership to the current user
        mode=0700
        owner="${USER}"
        shift
        ;;
      -*)
        # If an unknown argument is provided, call the 'softfail' function and exit
        softfail "Unknown argument: $1" || return $?
        ;;
      *)
        break
        ;;
    esac
  done

  # The directory path that is passed as the last argument
  local path="$1"

  # If mode is set, validate it and and apply the specified mode
  if [ -n "${mode:-}" ]; then
  
    # Ensure that the mode is numeric
    if ! [[ "${mode}" =~ ^[0-9]+$ ]]; then
      softfail "Invalid mode: Mode should be numeric" || return $?
    fi

    # Calculate umask value by subtracting mode from 0777
    local umask_value
    umask_value="$(printf "0%o" "$(( 0777 - "${mode}" ))")" || softfail "Failed to calculate umask value" || return $?

    # If sudo is enabled, run mkdir with the correct umask and directory path
    if [ "${sudo:-}" = true ]; then
      sudo --shell '$SHELL' -c "$(printf "umask %q && mkdir -p %q" "${umask_value}" "${path}")" \
        || softfail "Failed to create directory with sudo and specified mode" || return $?

    else
      # Otherwise, use the local shell to apply the umask and create the directory
      ( umask "${umask_value}" && mkdir -p "${path}" ) \
        || softfail "Failed to create directory with specified mode" || return $?
    fi

    # Ensure the directory has the correct access mode
    ${sudo:+"sudo"} chmod "${mode}" "${path}" || softfail "Failed to set permissions on the directory" || return $?
    
  else
    # Create the directory without setting a specific mode
    ${sudo:+"sudo"} mkdir -p "${path}" || softfail "Failed to create directory" || return $?
  fi

  # Set ownership if specified
  if [ -n "${owner:-}" ]; then
    # If no group is set, retrieve the default group for the user
    if [ -z "${group:-}" ]; then
      group="$(id -g -n "${owner}")" || softfail "Failed to retrieve group for owner '${owner}'" || return $?
    fi

    # Change the ownership of the directory
    ${sudo:+"sudo"} chown "${owner}:${group}" "${path}" || softfail "Failed to set ownership to ${owner}:${group}" || return $?
    
  # If only the group is set, change the group ownership
  elif [ -n "${group:-}" ]; then
    ${sudo:+"sudo"} chgrp "${group}" "${path}" || softfail "Failed to set group ownership to '${group}'" || return $?
  fi
}
