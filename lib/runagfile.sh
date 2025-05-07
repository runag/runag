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

# ## `runagfile::load`
#
# Loads a runagfile from the current directory or a known subdirectory.
#
# This function searches for a `runagfile.sh` script in the following locations:
#
# * Current directory:
#   * `runagfile.sh`
#   * `runagfile/runagfile.sh`
#   * `<name>-runagfile/runagfile.sh`, if there is exactly one matching directory
#
# If `--if-exists` is passed, the function exits silently if no runagfile is found.
#
# ### Usage
#
# runagfile::load [--if-exists]
#
# * `--if-exists`: suppresses the error if no runagfile is found
#
# ### Examples
#
# runagfile::load
# runagfile::load --if-exists
#
runagfile::load() {
  local if_exists=false

  # Parse optional command-line arguments
  while [ "$#" -gt 0 ]; do
    case "$1" in
      -e|--if-exists)
        if_exists=true
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

  # Attempt to load from the current directory
  if [ -f "runagfile.sh" ]; then
    # shellcheck disable=SC1091
    . "runagfile.sh"
    softfail --unless-good --status $? "Failed to load './runagfile.sh' (exit code $?)"
    return $?
  fi

  # Attempt to load from the runagfile/ subdirectory
  if [ -f "runagfile/runagfile.sh" ]; then
    # shellcheck disable=SC1091
    . "runagfile/runagfile.sh"
    softfail --unless-good --status $? "Failed to load './runagfile/runagfile.sh' (exit code $?)"
    return $?
  fi

  # Attempt to load from a *-runagfile/ directory if exactly one exists
  local matches=(*-runagfile)

  if [ "${#matches[@]}" -eq 1 ] && [ -d "${matches[0]}" ] && [ -f "${matches[0]}/runagfile.sh" ]; then
    # shellcheck disable=SC1091
    . "${matches[0]}/runagfile.sh"
    softfail --unless-good --status $? "Failed to load '${matches[0]}/runagfile.sh' (exit code $?)"
    return $?
  fi

  # Return silently if --if-exists was provided
  if [ "${if_exists}" = true ]; then
    return
  fi

  softfail "No 'runagfile.sh' found in any known location"
}
