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
# Ensures that a directory exists with specific permissions and ownership.
# 
# This function creates a directory at the specified path if it does not exist, applying custom permissions, ownership, and group as specified by the user. If no specific permissions or ownership are provided, defaults will be applied. Additionally, it supports running with elevated privileges if needed.
#
# #### Usage
#
# dir::ensure_exists [--mode <permissions>] [--owner <owner>] [--group <group>] [--sudo] [--for-me-only] <path>
# 
# Arguments:
# - --mode <permissions>: Specify the directory's permissions (numeric, e.g., 0755).
# - --owner <owner>: Specify the owner of the directory.
# - --group <group>: Specify the group ownership of the directory.
# - --sudo: If set, the function will use `sudo` to execute commands with elevated privileges.
# - --for-me-only: Set default permissions to 0700 and ownership to the current user. Overrides other options.
# - <path>: The directory path to be created or verified.
#
# #### Example
#
# dir::ensure_exists --mode 0755 --owner user --group admin /path/to/dir
# dir::ensure_exists --sudo --for-me-only /path/to/dir
#
dir::ensure_exists() {
  local mode
  local owner
  local group
  local sudo

  # The following commented line is not currently in use but could be used to fetch the group of the current user.
  # group="$(awk -F: -v user="${USER}" '$1 == user {print $4}' /etc/passwd)"

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
      -f|--for-me-only)
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

  # If mode is set, validate it and apply the correct permissions
  if [ -n "${mode:-}" ]; then
  
    # Ensure that the mode is numeric
    if ! [[ "${mode}" =~ ^[0-9]+$ ]]; then
      softfail "Mode should be numeric" || return $?
    fi

    # Calculate umask value by subtracting mode from 0777
    local umask_value
    umask_value="$(printf "0%o" "$(( 0777 - "${mode}" ))")" || softfail || return $?

    # If sudo is enabled, run mkdir with the correct umask and directory path
    if [ "${sudo:-}" = true ]; then
      sudo --shell '$SHELL' -c "$(printf "umask %q && mkdir -p %q" "${umask_value}" "${path}")" || softfail || return $?

    else
      # Otherwise, use the local shell to apply the umask and create the directory
      ( umask "${umask_value}" && mkdir -p "${path}" ) || softfail || return $?
    fi

    # If the directory exists, ensure it has the correct permissions
    ${sudo:+"sudo"} chmod "${mode}" "${path}" || softfail || return $?
  
  else
    # If no mode is specified, simply create the directory (with optional sudo)
    ${sudo:+"sudo"} mkdir -p "${path}" || softfail || return $?
  fi

  # If the owner is set, assign ownership to the directory
  if [ -n "${owner:-}" ]; then
    # If no group is set, retrieve the default group for the user
    if [ -z "${group:-}" ]; then
      group="$(id -g -n "${owner}")" || softfail || return $?
    fi

    # Change the ownership of the directory
    ${sudo:+"sudo"} chown "${owner}:${group}" "${path}" || softfail || return $?
    
  # If only the group is set, change the group ownership
  elif [ -n "${group:-}" ]; then
    ${sudo:+"sudo"} chgrp "${group}" "${path}" || softfail || return $?
  fi
}
