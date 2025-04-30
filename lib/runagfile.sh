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

# ## `runagfile::load`
#
# Loads a rùnagfile from the current directory or a known subdirectory.
#
# This function searches for a `runagfile.sh` script in the following locations:
#
# * Current directory:
#   * `runagfile.sh`
#   * `runagfile/runagfile.sh`
#   * `<name>-runagfile/runagfile.sh`, if there is exactly one matching directory
#
# If `--if-exists` is passed, the function exits silently if no rùnagfile is found.
#
# ### Usage
#
# runagfile::load [--if-exists]
#
# * `--if-exists`: suppresses the error if no rùnagfile is found
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
    . "runagfile.sh"
    softfail --unless-good --status $? "Failed to load './runagfile.sh' (exit code $?)"
    return $?
  fi

  # Attempt to load from the runagfile/ subdirectory
  if [ -f "runagfile/runagfile.sh" ]; then
    . "runagfile/runagfile.sh"
    softfail --unless-good --status $? "Failed to load './runagfile/runagfile.sh' (exit code $?)"
    return $?
  fi

  # Attempt to load from a *-runagfile/ directory if exactly one exists
  local matches=(*-runagfile)

  if [ "${#matches[@]}" -eq 1 ] && [ -d "${matches[0]}" ] && [ -f "${matches[0]}/runagfile.sh" ]; then
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
