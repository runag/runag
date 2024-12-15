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

  printf "\n" || fail

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
    task::add --header "Rùnag and rùnagfiles" || softfail || return $?
    
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

# ### `runag::command`
#
# - Constructs a function name by concatenating the arguments with `::`, replacing `-` with `_`.
# - Stops processing if an argument starts with `-`.
# - If `::env` functions are present, they are executed first to handle any setup.
# - Executes the identified function with the remaining arguments.
#
# #### Parameters:
#
# - The function accepts a variable number of arguments.
#
# #### Example:
#
# ```bash
# runag::command action sub-action some-name --some-arg
# ```
# In this case, the function will:
# - Execute `action::env` and `action::sub_action::env` (if they exist) with the remaining arguments.
# - Execute `action::sub_action` (if it exists) with the remaining arguments.
# - If `action::sub_action` does not exist but `action` does, execute `action` with the remaining arguments.
#
# #### Notes:
#
# - The function uses `declare -F` to check for the existence of functions.
# - It handles errors gracefully with `softfail` if the `::env` function fails to execute correctly.
#
runag::command() {
  # Declare local variables to store potential function names and indices
  local try_name
  local found_name
  local found_index

  local i=1 # Initialize pointer variable (index) to iterate through arguments
  local item # Variable to store individual items in the argument list

  # Start a loop to iterate through all arguments
  while [ $i -le $# ]; do
    # Access each argument by its index using indirect variable reference
    item="${!i}"

    # If the current argument starts with a dash (indicating a flag or option), stop processing
    if [[ "${item}" == -* ]]; then
      break
    fi

    # If try_name is set, concatenate it with the current argument, separated by "::".
    # If try_name is not set, use the current argument as is.
    # Replace hyphens with underscores in the current argument.
    try_name="${try_name:+"${try_name}::"}${item//-/_}"

    # Check if a function with the name `try_name` exists
    if declare -F "${try_name}" >/dev/null; then
      # If the function is found, store the function name and the argument index
      found_name="${try_name}"
      found_index="$i"
    fi

    # Check if a function with the name `${try_name}::env` exists
    if declare -F "${try_name}::env" >/dev/null; then
      # If the `::env` function is found, run it with the remaining arguments
      "${try_name}::env" "${@:i+1}"

      # If `::env` execution fails, handle the error using `softfail`
      softfail --unless-good --exit-status $? "Error: Failed to run ${try_name}::env ($?)" || return $?
    fi

    # Increment the index to move to the next argument
    ((i++))
  done

  # If a valid function name was found, execute it with the remaining arguments
  if [ -n "${found_name:-}" ]; then
    "${found_name}" "${@:found_index+1}"
  else
    # If no valid function was found, handle the error gracefully
    softfail --unless-good --exit-status $? "Error: Unable to find suitable function for the arguments: $*" || return $?
  fi
}
