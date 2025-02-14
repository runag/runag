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

# ### `fail`
#
# Manages process termination with error handling, optional status overrides, and stack trace logging.
#
# #### Usage
#
# fail [OPTIONS] [MESSAGE]
#
# Options:
# -s, --status <code>        Set the exit status code (default: 1)
# -g, --unless-good          Skip termination if the status code is 0
# -u, --unless <range>       Ignore specified exit statuses or ranges (e.g., "2,4,6-8")
# -t, --soft                 Perform a soft failure (return instead of exiting)
#
# #### Example
#
# fail --status 2 "A critical error occurred"
# fail --status $? --unless 1,2,5-10 "Skipping failure for permitted statuses"
#

fail() {
  local exit_status=1          # Default exit status if not specified
  local unless_good=false      # Whether to skip failure if the exit status is 0
  local ignore_statuses        # Comma-separated list of statuses/ranges to ignore
  local perform_softfail=false # Whether to return instead of exiting
  local trace_start=1          # Stack trace starts at this level
  local message                # Error message to display

  # Parse command-line arguments
  while [ "$#" -gt 0 ]; do
    case "$1" in
      -s|--status)
        # Set exit status
        if [ -z "${2:-}" ] || [[ "$2" =~ ^- ]]; then
          { declare -F "log::error" >/dev/null && log::error "Error: Missing argument for $1 option"; } || echo "Error: Missing argument for $1 option" >&2
          shift
        elif [[ ! "$2" =~ ^[0-9]+$ || "$2" -lt 0 || "$2" -gt 255 ]]; then
          { declare -F "log::error" >/dev/null && log::error "Error: Invalid status code: '$2'. It must be a number between 0 and 255."; } || echo "Error: Invalid status code: '$2'. It must be a number between 0 and 255." >&2
          shift 2
        else
          exit_status="$2"
          shift 2
        fi
        ;;
      -g|--unless-good)
        # Skip termination if exit_status is 0
        unless_good=true
        shift
        ;;
      -u|--unless)
        # Set ignored statuses or status ranges
        if [ -z "${2:-}" ] || [[ "$2" =~ ^- ]]; then
          { declare -F "log::error" >/dev/null && log::error "Error: Missing argument for $1 option"; } || echo "Error: Missing argument for $1 option" >&2
          shift
        else
          ignore_statuses="$2"
          shift 2
        fi
        ;;
      -f|--soft)
        # Enable soft failure (return instead of exit)
        perform_softfail=true
        shift
        ;;
      -w|--from-softfail-wrapper)
        # Enable soft failure (return instead of exiting) and adjust the stack trace starting point
        perform_softfail=true
        trace_start=2
        shift
        ;;
      -*)
        # Handle unrecognized arguments
        { declare -F "log::error" >/dev/null && log::error "Error: Unrecognized argument for fail: $1"; } || echo "Error: Unrecognized argument for fail: $1" >&2
        shift
        message="$*"
        break
        ;;
      *)
        # Capture the failure message
        message="$*"
        break
        ;;
    esac
  done

  # Default message if none was provided
  if [ -z "${message:-}" ]; then
    message="Abnormal termination"
  fi

  # If unless-good is set and exit_status is 0, return without failing
  if [ "${unless_good}" = true ] && [ "${exit_status}" = 0 ]; then
    return 0
  fi

  # Handle ignored statuses or ranges
  if [ -n "${ignore_statuses:-}" ]; then
    local ignore_array ignore_item ignore_start ignore_end

    IFS=',' read -ra ignore_array <<< "${ignore_statuses}"

    for ignore_item in "${ignore_array[@]}"; do
      if [[ "${ignore_item}" =~ ^[0-9]+-[0-9]+$ ]]; then
        # Handle range: Extract ignore_start and ignore_end
        IFS='-' read -r ignore_start ignore_end <<< "${ignore_item}"
        if (( exit_status >= ignore_start && exit_status <= ignore_end )); then
          return 0
        fi
      else
        # Ensure it's a valid numeric value
        if ! [[ "${ignore_item}" =~ ^[0-9]+$ ]]; then
          { declare -F "log::error" >/dev/null && log::error "Error: Ignore pattern is not numeric: ${ignore_item}"; } || echo "Error: Ignore pattern is not numeric: ${ignore_item}" >&2
        elif [[ "${exit_status}" = "${ignore_item}" ]]; then
          return 0
        fi
      fi
    done
  fi

  # Ensure exit_status is not 0 to prevent unintended success status
  if [ "${exit_status}" = 0 ]; then
    exit_status=1
  fi

  # Log error message
  { declare -F "log::error" >/dev/null && log::error "${message}"; } || echo "${message}" >&2

  # Provide a stack trace
  local trace_line trace_index trace_end=$((${#BASH_LINENO[@]}-1))
  for ((trace_index=trace_start; trace_index<=trace_end; trace_index++)); do
    trace_line="  ${BASH_SOURCE[${trace_index}]}:${BASH_LINENO[$((trace_index-1))]}: in \`${FUNCNAME[${trace_index}]}'"
    { declare -F "log::error" >/dev/null && log::error "${trace_line}"; } || echo "${trace_line}" >&2
  done

  # If soft failure is enabled, return instead of exiting
  if [ "${perform_softfail}" = true ]; then
    return "${exit_status}"
  fi

  # Exit with the provided status
  exit "${exit_status}"
}

# ### `softfail`
#
# A variation of `fail` that only returns an error status without terminating the process.
#
# #### Usage
#
# softfail [OPTIONS] [MESSAGE]
#
# #### Example
#
# softfail --status 3 "Warning: A problem occurred, but the process will continue."
#

softfail() {
  fail --from-softfail-wrapper "$@"
}

# ### `fail::function_sources`
#
# Outputs the source code of `fail` and `softfail` functions.
#
# #### Usage
#
# fail::function_sources
#
# #### Example
#
# fail::function_sources || echo "Required functions are missing."
#

fail::function_sources() {
  declare -f fail || softfail || return $?
  declare -f softfail || softfail || return $?
}
