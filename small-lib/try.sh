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

# Runs a command and prints a warning if it fails.
# Usage: try_warn <command> [args...]
try_warn() {
  "$@" # Run the command with all passed arguments
  local status=$? # Capture the exit status of the command

  if [ $status -ne 0 ]; then
    # Print error message and the failed command to stderr
    echo "Warning: Command failed with exit status $status: $*" >&2

    # Print a stack trace
    local i
    for (( i=1; i < ${#BASH_LINENO[@]}; i++ )); do
      printf "    at %s (%s:%s)\n" "${FUNCNAME[i]}" "${BASH_SOURCE[i]}" "${BASH_LINENO[i-1]}" >&2
    done
  fi

  # Return the original status code
  return $status
}

# Runs a command and exits the script with error reporting if it fails.
# Usage: try_exit <command> [args...]
try_exit() {
  "$@" # Run the command with all passed arguments
  local status=$? # Capture the exit status of the command

  if [ $status -ne 0 ]; then
    # Print error message and the failed command to stderr
    echo "Error: Command failed with exit status $status: $*" >&2

    # Print a stack trace
    local i
    for (( i=1; i < ${#BASH_LINENO[@]}; i++ )); do
      printf "    at %s (%s:%s)\n" "${FUNCNAME[i]}" "${BASH_SOURCE[i]}" "${BASH_LINENO[i-1]}" >&2
    done

    # Exit with the original status code
    exit $status
  fi

  return 0
}
