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

# ### `runag::mini_library`
#
# This function generates a minimal bash script preamble used for producing derivative scripts from Rùnag code. 
# It outputs the shebang line, prints the project's license information, and optionally enables the 'nounset' 
# shell option to treat unset variables as errors. Additionally, it outputs the source code of the `fail`, `softfail`, 
# `dir::ensure_exists`, and `file::write` functions.
#
# #### Parameters:
#
# - `--nounset`: An optional argument. When provided, it enables the 'nounset' option, causing the shell 
#   to treat unset variables as errors.
#
runag::mini_library() {
  # Output the shebang for the script to specify the interpreter.
  printf "#!/usr/bin/env bash\n\n" || fail "Failed to print the shebang line."

  # Print the license information.
  # shellcheck disable=SC2015
  runag::print_license && printf "\n" || fail "Error printing license information."

  # If the argument is '--nounset', set the nounset option to treat unset variables as errors.
  if [ "${1:-}" = "--nounset" ]; then
    printf "set -o nounset\n\n" || fail "Failed to print 'nounset' option."
  fi

  # Output the code for the functions
  declare -f fail || softfail "The 'fail' function is not defined." || return $?
  declare -f softfail || softfail "The 'softfail' function is not defined." || return $?
  declare -f dir::ensure_exists || softfail "The 'dir::ensure_exists' function is not defined." || return $?
  declare -f file::write || softfail "The 'file::write' function is not defined." || return $?
}

# ### `runag::print_license`
#
# This function prints the copyright and licensing information for the Rùnag project.
# It includes the project's copyright notice and specifies that the project is licensed under the Apache License, Version 2.0.
#
runag::print_license() {
  cat <<SHELL
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
SHELL
}

# ### `runag::invoke`
#
# This function is responsible for invoking the appropriate function based on the provided arguments.
#
# - Constructs a function name by combining the arguments with `::`, replacing `-` with `_`.
# - Stops processing if an argument starts with `-` (indicating a flag).
# - If `::env` functions are defined, they are invoked first to perform any setup.
# - Invokes the identified function with the remaining arguments.
#
# #### Flags:
#
# - `--no-subshell` (`-n`): If this flag is provided, the function is invoked without using a subshell.
#   By default, the function is invoked within a subshell to prevent any modifications to the current shell environment.
#   When `--no-subshell` is specified, the function runs in the current shell environment.
#
# #### Parameters:
#
# - The function accepts a variable number of arguments.
#
# #### Example:
#
# ```bash
# runag::invoke action sub-action some-name --some-arg
# ```
#
# In this case, the function will:
#
# - Call `action::env` and `action::sub_action::env` (if they exist) to handle setup tasks with the remaining arguments.
# - Call `action::sub_action` (if it exists) with the remaining arguments.
# - If `action::sub_action` does not exist but `action` does, call `action` with the remaining arguments.
#
runag::invoke() {
  local no_subshell=false

  # Parse optional flags before processing the arguments.
  while [ "$#" -gt 0 ]; do
    case "$1" in
      -n|--no-subshell)
        no_subshell=true
        shift
        ;;
      *)
        break  # Stop flag parsing
        ;;
    esac
  done

  if [ "${no_subshell}" = true ]; then
    runag::invoke::perform "$@"  # Invoke without using a subshell.
  else
    ( runag::invoke::perform "$@" )  # Invoke in a subshell.
  fi
}

# ### `runag::invoke::perform`
#
# This function performs the core logic of invoking the appropriate function based on the provided arguments.
# It iterates over the arguments, constructs a function name, checks for matching functions, and calls the function.
# If a `::env` setup function exists, it is called before the main function.
# If no suitable function is found, an error is logged.
#
# #### Parameters:
#
# - A variable number of arguments representing the function name and parameters.
#
# #### Example:
#
# ```bash
# runag::invoke::perform action sub-action some-name
# ```
# This will attempt to call the `action::sub_action` function, invoking its corresponding `::env` setup function if defined.
#
runag::invoke::perform() {
  # Exit if no arguments are provided.
  if [ $# -eq 0 ]; then
    softfail "Error: No arguments provided. Usage: runag::invoke <action> [...args]"
    return $?
  fi
  
  # Declare local variables to track potential function names and indices.
  local try_name       # Candidate function name.
  local found_name     # Valid function name that will be invoked.
  local found_index    # Index where the function name was found.

  local i=1            # Index to iterate through arguments.
  local item           # Current argument being processed.

  # Iterate through all arguments until a flag (starting with '-') is encountered.
  while [ $i -le $# ]; do
    item="${!i}" # Access the current argument via indirect referencing.

    # Stop processing if an argument starts with a dash (indicating a flag).
    if [[ "${item}" == -* ]]; then
      break
    fi

    # Construct the candidate function name:
    # Append "::" to the previous name and replace hyphens with underscores.
    try_name="${try_name:+"${try_name}::"}${item//-/_}"

    # Check if a function named `try_name` exists.
    if declare -F "${try_name}" >/dev/null; then
      # Save the function name and index for later invocation.
      found_name="${try_name}"
      found_index="$i"
    fi

    # Check if a setup function named `${try_name}::env` exists.
    if declare -F "${try_name}::env" >/dev/null; then
      # Invoke the setup function with the remaining arguments.
      "${try_name}::env" "${@:i+1}"

      # Handle errors gracefully if the `::env` function call fails.
      softfail --unless-good --exit-status $? "Error: Failed to invoke ${try_name}::env ($?)" || return $?
    fi

    ((i++)) # Move to the next argument.
  done

  # If a valid function name was found, call it with the remaining arguments.
  if [ -n "${found_name:-}" ]; then
    "${found_name}" "${@:found_index+1}"
  else
    # Handle the case where no matching function is found.
    softfail "Error: No suitable function found for the provided arguments: $*"
    return $?
  fi
}

# ### `runag::invocation_target`
#
# This function identifies the function name to be invoked based on the provided arguments.
# It constructs the function name by concatenating arguments with `::` and replacing hyphens (`-`) with underscores (`_`).
# If a matching function is found, it returns the function name. If no matching function is found, an error is logged.
#
# #### Parameters:
#
# - A variable number of arguments representing the function name and parameters.
#
# #### Example:
#
# ```bash
# runag::invocation_target action sub-action some-name
# ```
# This will attempt to identify and return the target function name (`action::sub_action` in this case) if it exists.
#
runag::invocation_target() {
  # Exit if no arguments are provided.
  if [ $# -eq 0 ]; then
    softfail "Error: No arguments provided"
    return $?
  fi

  # Declare local variables to track potential function names and indices.
  local try_name       # Candidate function name.
  local found_name     # Valid function name that will be invoked.

  local i=1            # Index to iterate through arguments.
  local item           # Current argument being processed.

  # Iterate through all arguments until a flag (starting with '-') is encountered.
  while [ $i -le $# ]; do
    item="${!i}" # Access the current argument via indirect referencing.

    # Stop processing if an argument starts with a dash (indicating a flag).
    if [[ "${item}" == -* ]]; then
      break
    fi

    # Construct the candidate function name:
    # Append "::" to the previous name and replace hyphens with underscores.
    try_name="${try_name:+"${try_name}::"}${item//-/_}"

    # Check if a function named `try_name` exists.
    if declare -F "${try_name}" >/dev/null; then
      # Store the function name for later use.
      found_name="${try_name}"
    fi

    ((i++)) # Move to the next argument.
  done

  # If a valid function name was found, return it.
  if [ -n "${found_name:-}" ]; then
    echo "${found_name}"
  else
    # Handle the case where no matching function is found.
    softfail "Error: No suitable function found for the provided arguments: $*"
    return $?
  fi
}
