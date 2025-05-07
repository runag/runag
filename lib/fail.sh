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

# ## `fail`
#
# Prints an error message, logs a stack trace, and exits or returns based on provided options.
#
# ### Usage
#
# fail [OPTIONS] [MESSAGE]
#
# Options:
#   -s, --status <code>          Set the exit status code (default: 1)
#   -g, --unless-good            Skip termination if the status code is 0
#   -u, --unless <range>         Comma-separated list of status codes or ranges to ignore (e.g., "1,3,5-7")
#   -f, --soft                   Perform a soft failure (return instead of exiting)
#   -w, --from-softfail-wrapper  Return instead of exiting and shift the stack trace origin by one level
#
# Arguments:
#   [MESSAGE]                    Optional error message to display
#
# ### Examples
#
# fail
#   Exit with default status 1 and print a generic error message.
#
# fail --soft "An error occurred but it's manageable"
#   Print the message and return instead of exiting.
#
# fail "A critical error occurred"
#   Exit with status 1 and print a custom error message.
#
# fail --unless-good "A critical error occurred"
#   Only exit if the status is non-zero; otherwise, do nothing.
#
# fail --status $? "A critical error occurred and the current status should be preserved"
#   Exit using the current process status and print the message.
#
# fail --status $? --unless 1,2,5-10 "Skipping failure for permitted statuses"
#   Exit only if the current status is not in the allowed list; otherwise, return without error.
#
fail() {
  local exit_status=1           # Default exit status if not specified
  local unless_good=false       # Whether to skip failure if the exit status is 0
  local ignore_statuses         # Comma-separated list of statuses/ranges to ignore
  local perform_softfail=false  # Whether to return instead of exiting
  local trace_start=1           # Stack trace starts at this level
  local message                 # Error message to display

  # Parse command-line arguments
  while [ "$#" -gt 0 ]; do
    case "$1" in
      -s|--status)
        # Validate and set exit status code
        if [ -z "${2:-}" ] || [[ "$2" =~ ^- ]]; then
          printf "Missing argument for '%s' option.\n" "$1" >&2
          shift
        elif [[ ! "$2" =~ ^[0-9]+$ || "$2" -lt 0 || "$2" -gt 255 ]]; then
          printf "Status code '%s' must be a number between 0 and 255.\n" "$2" >&2
          shift 2
        else
          exit_status="$2"
          shift 2
        fi
        ;;
      -g|--unless-good)
        # Do not fail if the exit status is 0
        unless_good=true
        shift
        ;;
      -u|--unless)
        # Set list of exit statuses or ranges to ignore
        if [ -z "${2:-}" ] || [[ "$2" =~ ^- ]]; then
          printf "Missing argument for '%s' option.\n" "$1" >&2
          shift
        else
          ignore_statuses="$2"
          shift 2
        fi
        ;;
      -f|--soft)
        # Perform soft failure (return instead of exiting)
        perform_softfail=true
        shift
        ;;
      -w|--from-softfail-wrapper)
        # Perform soft failure with adjusted stack trace offset
        perform_softfail=true
        trace_start=2
        shift
        ;;
      -*)
        # Handle unknown options
        printf "Unrecognized argument: '%s'.\n" "$1" >&2
        shift
        message="$*"
        break
        ;;
      *)
        # Capture remaining input as the failure message
        message="$*"
        break
        ;;
    esac
  done

  # Default to a generic message if none was provided
  if [ -z "${message:-}" ]; then
    message="An error occurred; refer to the stack trace for context."
  fi

  # Skip failure if allowed and status is 0
  if [ "${unless_good}" = true ] && [ "${exit_status}" = 0 ]; then
    return 0
  fi

  # Check if current exit_status should be ignored
  if [ -n "${ignore_statuses:-}" ]; then
    local ignore_array ignore_item ignore_start ignore_end

    # Split the comma-separated ignore list into an array
    IFS=',' read -ra ignore_array <<< "${ignore_statuses}"

    # Iterate through each item in the ignore list.
    for ignore_item in "${ignore_array[@]}"; do
      if [[ "${ignore_item}" =~ ^[0-9]+-[0-9]+$ ]]; then
        # Handle numeric range (e.g., "4-7")
        IFS='-' read -r ignore_start ignore_end <<< "${ignore_item}"
        if (( exit_status >= ignore_start && exit_status <= ignore_end )); then
          return 0
        fi
      else
        # Validate numeric status (e.g., "2")
        if ! [[ "${ignore_item}" =~ ^[0-9]+$ ]]; then
          printf "Ignored pattern '%s' is not a valid number or range.\n" "${ignore_item}" >&2
        elif [[ "${exit_status}" = "${ignore_item}" ]]; then
          return 0
        fi
      fi
    done
  fi

  # Normalize status to non-zero
  if [ "${exit_status}" = 0 ]; then
    exit_status=1
  fi

  local error_prefix="[ERROR] " error_postfix=""

  # Set color formatting if stderr is a terminal
  if [ -t 2 ]; then
    error_prefix="$(printf "setaf 9\nbold" | tput -S 2>/dev/null)"
    error_postfix="$(tput sgr 0 2>/dev/null)"
  fi

  # Print error message
  printf "%s%s%s\n" "${error_prefix}" "${message}" "${error_postfix}" >&2

  # Print stack trace
  local trace_index trace_end=$((${#BASH_LINENO[@]} - 1))
  for ((trace_index=trace_start; trace_index<=trace_end; trace_index++)); do
    printf "%s    at %s (%s:%s)%s\n" "${error_prefix}" "${FUNCNAME[${trace_index}]}" "${BASH_SOURCE[${trace_index}]}" "${BASH_LINENO[$((trace_index-1))]}" "${error_postfix}" >&2
  done

  # Return or exit depending on failure type
  if [ "${perform_softfail}" = true ]; then
    return "${exit_status}"
  fi

  # Terminate the script with the specified exit status.
  exit "${exit_status}"
}

# ## `softfail`
#
# Calls `fail` in soft-fail mode, which prints a message and returns instead of exiting.
#
# ### Usage
#
# softfail [OPTIONS] [MESSAGE]
#
# Options:
#   -s, --status <code>   Set the exit status code (default: 1)
#   -g, --unless-good     Skip termination if the status code is 0
#   -u, --unless <range>  Comma-separated list of status codes or ranges to ignore (e.g., "1,3,5-7")
#
# Arguments:
#   [MESSAGE]             Optional error message to display
#
# ### Examples
#
# softfail --status 2 --unless-good --unless 3,4-6 "A problem occurred, but continuing."
#
# shellcheck disable=SC2120
softfail() {
  fail --from-softfail-wrapper "$@"
}
