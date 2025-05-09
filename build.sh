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

# Treat unset variables as an error
set -o nounset

# Exit if there are uncommitted changes in the working directory or staging area.
if ! git diff --quiet || ! git diff --cached --quiet; then
  echo "Uncommitted changes detected. Please commit or stash your work before proceeding."
  exit 1
fi

# Load the Runag library for use in script building
# shellcheck disable=SC1091
source index.sh || { echo "Failed to load the Runag library." >&2; exit 1; }


# --- Build the bin/runag script

# Set the script file name
script_file="runag"

# Create a temporary file to assemble the script
temp_file="$(mktemp)" || fail "Could not create a temporary file."

{
  # Write the shebang to specify the Bash interpreter
  printf "#!/usr/bin/env bash\n\n" || fail "Could not write the shebang line."

  # Insert the license header from the Runag library
  runag::print_license && printf "\n" || fail "Could not write license information."

  # Add a comment indicating the commit this build was generated from
  printf "# This script was built from commit " || fail "Could not write commit comment."
  git rev-parse HEAD && printf "\n" || fail "Could not retrieve the Git commit hash."

  # Include shell configuration section
  file::read_section set_shell_options "bin/${script_file}" && printf "\n" ||
    fail "Could not read the 'set_shell_options' section from bin/${script_file}."

  # Output all currently defined functions
  declare -f || fail "Could not output all currently defined functions."

  # Include the script invocation logic
  printf "\n" && file::read_section invoke_command "bin/${script_file}" ||
    fail "Could not read the 'invoke_command' section from bin/${script_file}."

} >"${temp_file}" || fail "Could not write assembled content to temporary file."

# Move the newly built script to its destination with proper permissions
file::write --consume "${temp_file}" --mode 0755 "dist/${script_file}" ||
  fail "Could not write the newly built script to 'dist/${script_file}'."


# --- Build the dist/ssh-call script

# Set the script file name
script_file="ssh-call"

# Create a temporary file to assemble the script
temp_file="$(mktemp)" || fail "Could not create a temporary file."

{
  # Write the shebang to specify the Bash interpreter
  printf "#!/usr/bin/env bash\n\n" || fail "Could not write the shebang line."

  # Insert the license header from the Runag library
  runag::print_license && printf "\n" || fail "Could not write license information."

  # Add a comment indicating the commit this build was generated from
  printf "# This script was built from commit " || fail "Could not write commit comment."
  git rev-parse HEAD && printf "\n" || fail "Could not retrieve the Git commit hash."

  # Include shell configuration section
  file::read_section set_shell_options "bin/${script_file}" && printf "\n" ||
    fail "Could not read the 'set_shell_options' section from bin/${script_file}."

  # Output utility functions
  declare -f fail &&
  declare -f softfail &&
  declare -f dir::ensure_exists ||
    fail "Required utility functions are missing."

  # Output ssh::call functions
  declare -f ssh::call &&
  declare -f ssh::call::internal &&
  declare -f ssh::call::set_ssh_args &&
  declare -f ssh::call::produce_script &&
  declare -f ssh::call::interactive_terminal_functions_filter &&
  declare -f ssh::call::invoke ||
    fail "Required ssh::call functions are missing."

  # Include the script invocation logic
  printf "\n" && file::read_section invoke_command "bin/${script_file}" ||
    fail "Could not read the 'invoke_command' section from bin/${script_file}."

} >"${temp_file}" || fail "Could not write assembled content to temporary file."

# Move the newly built script to its destination with proper permissions
file::write --consume "${temp_file}" --mode 0755 "dist/${script_file}" ||
  fail "Could not write the newly built script to 'dist/${script_file}'."


# Add the built executables to the staging area
git add dist/runag || fail "Failed to add 'dist/runag' to the staging area."
git add dist/ssh-call || fail "Failed to add 'dist/ssh-call' to the staging area."

# Commit the changes to the repository
git commit -m "Add built executables for runag and ssh-call

* Bundles the required library functions for standalone usage
* Includes the built 'dist/runag' executable
* Includes the built 'dist/ssh-call' executable
* Generated using the 'build.sh' script" ||
  fail "Failed to commit the built executables."
