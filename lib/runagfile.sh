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

# ### `runagfile::add`
#
# This function adds a repository to the system by cloning it from GitHub 
# into the user's runagfiles collection directory.
#
# #### Parameters:
# 
# - `repository` (string): The path to the repository, formatted as "username/repository". 
#
runagfile::add() {
  local user_name
  local repo_name

  # Parse the input string to extract the GitHub username and repository name.
  # The string should be in the format "username/repository".
  IFS="/" read -r user_name repo_name <<< "$1" || softfail "Failed to parse the input string into the username and repository name" || return $?

  # Attempt to clone the repository and place it in the designated directory.
  # The repository is cloned into a folder named after the repository and username,
  # with the suffix '-github' to avoid conflicts.
  git::place_up_to_date_clone \
    "https://github.com/${user_name}/${repo_name}.git" \
    "${HOME}/.runag/runagfiles/${repo_name}-${user_name}-github" \
    || softfail "Failed to clone the repository from GitHub: https://github.com/${user_name}/${repo_name}.git" || return $?
}

# ### `runagfile::add_from_list`
#
# This function processes a list of repositories and attempts to add each one 
# by calling `runagfile::add` for each repository path provided in the list.
#
# #### Parameters:
#
# - This function expects a list of repository paths, one per line, from standard input. 
#   Each line should be in the format "username/repository".
#
runagfile::add_from_list() {
  local line
  
  # Read each line from input. For each line that is not empty, call the `runagfile::add` function.
  while IFS="" read -r line; do
    if [ -n "${line}" ]; then
      # Attempt to add the repository using the `runagfile::add` function.
      runagfile::add "${line}" || softfail "Unable to add rùnagfile ${line}" || return $?
    fi
  done || softfail "Unable to add rùnagfiles from list" || return $?
}

# ### `runagfile::load`
#
# This function locates and loads a rùnagfile.
#
# Possible locations for the `runagfile.sh` script:
#
# - In the current working directory:
#   - `./runagfile.sh`
#   - `./runagfile/runagfile.sh`
#
# If the script is not found in the local directory, the function will attempt to load all rùnagfiles 
# from the user's collection:
#
# - `${HOME}/.runag/runagfiles/*/runagfile.sh`
# - `${HOME}/.runag/runagfiles/*/runagfile/runagfile.sh`
#
# #### Parameters:
# 
# - `-w` or `--working-directory-only`: If provided, this option restricts the function to loading
# runagfile.sh only from the current directory, without searching the rùnagfiles collection.
#
runagfile::load() {
  # Flag to indicate whether only the current working directory should be considered.
  local working_directory_only=false

  # Parse the command-line arguments.
  while [ "$#" -gt 0 ]; do
    case "$1" in
      -w|--working-directory-only)
        working_directory_only=true
        shift
        ;;
      -*)
        softfail "Unknown argument: $1" || return $?
        ;;
      *)
        break # Break the loop if no more recognized arguments.
        ;;
    esac
  done

  # Attempt to source the `runagfile.sh` from the current directory.
  if [ -f "./runagfile.sh" ]; then
    . "./runagfile.sh"
    softfail --unless-good --status $? "Failed to load './runagfile.sh' ($?)" || return $?

  # Attempt to source the `runagfile.sh` from within the `runagfile` directory.
  elif [ -f "./runagfile/runagfile.sh" ]; then
    . "./runagfile/runagfile.sh"
    softfail --unless-good --status $? "Failed to load './runagfile/runagfile.sh' ($?)" || return $?

  # If the `-w` flag was not specified, search the user's rùnagfiles collection for the `runagfile.sh`.
  elif [ "${working_directory_only}" = false ] && [ -d "${HOME}/.runag/runagfiles" ]; then
    local dir_path

    # Iterate over the directories within the rùnagfiles collection.
    for dir_path in "${HOME}/.runag/runagfiles/"*; do

      # If `runagfile.sh` is found, source it.
      if [ -f "${dir_path}/runagfile.sh" ]; then
        . "${dir_path}/runagfile.sh"
        softfail --unless-good --status $? "Failed to load '${dir_path}/runagfile.sh' ($?)" || return $?

      # If `runagfile/runagfile.sh` is found, source it.
      elif [ -f "${dir_path}/runagfile/runagfile.sh" ]; then
        . "${dir_path}/runagfile/runagfile.sh"
        softfail --unless-good --status $? "Failed to load '${dir_path}/runagfile/runagfile.sh' ($?)" || return $?
      fi
    done
  fi
}
