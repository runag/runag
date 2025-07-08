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

# Print an error message and return an optional status code (default: 1).
# Prints a stack trace for debugging.
#
# Usage: softfail [message] [exit_status]
# Examples:
#   softfail
#   softfail "An unexpected error occurred."
#   softfail "An unexpected error occurred." 2
softfail() {
  local message="${1:-"Script exited with an error."}"

  # If stderr is a terminal, print bold red message
  if [ -t 2 ]; then
    printf "%s%s%s\n" "$(printf "setaf 9\nbold" | tput -S 2>/dev/null)" "$message" "$(tput sgr 0 2>/dev/null)" >&2
  else
    # Otherwise, print plain error message
    printf "Error: %s\n" "${message}" >&2
  fi

  # Print stack trace
  local i
  for (( i=1; i < ${#BASH_LINENO[@]}; i++ )); do
    printf "    at %s (%s:%s)\n" "${FUNCNAME[i]}" "${BASH_SOURCE[i]}" "${BASH_LINENO[i-1]}" >&2
  done

  return "${2:-1}"
}

# Exit the script with an error message and optional status code (default: 1).
# Prints a stack trace for debugging.
#
# Usage: fail [message] [exit_status]
# Example:
#   fail
#   fail "An unexpected error occurred."
#   fail "An unexpected error occurred." 2
fail() {
  softfail "$1"
  exit "${2:-1}"
}
