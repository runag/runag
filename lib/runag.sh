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

runag::mini_library() {
  printf "#!/usr/bin/env bash\n\n" || fail

  runag::print_license || fail

  printf "\n"

  if [ "${1:-}" = "--nounset" ]; then
    printf "set -o nounset\n\n" || fail
  fi

  declare -f fail || softfail || return $?
  declare -f softfail || softfail || return $?
  declare -f dir::should_exists || softfail || return $?
  declare -f file::write || softfail || return $?
}

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

runag::tasks() {
  if [ -d "${HOME}/.runag" ]; then
    # Rùnag and rùnagfiles (task header)
    
    task::add runag::create_or_update_offline_install || softfail || return $?
    task::add runag::update_current_offline_install || softfail || return $?
  fi
}

runag::update_current_offline_install() {
  local runag_path="${HOME}/.runag"

  if [ ! -d "${runag_path}/.git" ]; then
    softfail "Unable to find rùnag checkout" || return $?
  fi

  local remote_path; remote_path="$(git -C "${runag_path}" config "remote.offline-install.url")" || softfail || return $?
 
  runag::create_or_update_offline_install "${remote_path}/.." || softfail || return $?
}

runag::create_or_update_offline_install() (
  local runag_path="${HOME}/.runag"

  if [ -n "$1" ]; then
    cd "$1" || softfail || return $?
  fi

  local target_directory="${PWD}" || softfail || return $?

  if [ ! -d "${runag_path}/.git" ]; then
    softfail "Unable to find rùnag checkout" || return $?
  fi

  local runag_remote_url; runag_remote_url="$(git -C "${runag_path}" remote get-url origin)" || softfail || return $?

  git -C "${runag_path}" pull origin main || softfail || return $?
  git -C "${runag_path}" push --set-upstream origin main || softfail || return $?

  git::create_or_update_mirror "${runag_remote_url}" runag.git || softfail || return $?

  ( cd "${runag_path}" && git::add_or_update_remote "offline-install" "${target_directory}/runag.git" && git fetch "offline-install" ) || softfail || return $?

  dir::should_exists --mode 0700 "runagfiles" || softfail || return $?

  local runagfile_path; for runagfile_path in "${runag_path}/runagfiles"/*; do
    if [ -d "${runagfile_path}" ]; then
      local runagfile_dir_name; runagfile_dir_name="$(basename "${runagfile_path}")" || softfail || return $?
      local runagfile_remote_url; runagfile_remote_url="$(git -C "${runagfile_path}" remote get-url origin)" || softfail || return $?

      git -C "${runagfile_path}" pull origin main || softfail || return $?
      git -C "${runagfile_path}" push --set-upstream origin main || softfail || return $?

      git::create_or_update_mirror "${runagfile_remote_url}" "runagfiles/${runagfile_dir_name}" || softfail || return $?

      ( cd "${runagfile_path}" && git::add_or_update_remote "offline-install" "${target_directory}/runagfiles/${runagfile_dir_name}" && git fetch "offline-install" ) || softfail || return $?
    fi
  done

  cp -f "${runag_path}/deploy-offline.sh" . || softfail || return $?
)

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
    runag::invoke::actual "$@"  # Invoke without using a subshell.
  else
    ( runag::invoke::actual "$@" )  # Invoke in a subshell.
  fi
}

# ### `runag::invoke::actual`
#
# This function performs the core logic of invoking the appropriate function based on the provided arguments.
# It iterates over the arguments, constructs a function name, checks for matching functions, and calls the function.
# If a `::env` setup function exists, it is called before the main function.
# If no suitable function is found, an error is logged.
#
# #### Parameters:
# - A variable number of arguments representing the function name and parameters.
#
# #### Example:
# ```bash
# runag::invoke::actual action sub-action some-name
# ```
# This will attempt to call the `action::sub_action` function, invoking its corresponding `::env` setup function if defined.
#
runag::invoke::actual() {
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
# - A variable number of arguments representing the function name and parameters.
#
# #### Example:
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
