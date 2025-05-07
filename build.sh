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

# Build the bin/runag script
# --------------------------

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
  file::read_section set_shell_options bin/runag && printf "\n" ||
    fail "Could not read the 'set_shell_options' section from bin/runag."

  # Output all currently defined functions
  declare -f || fail "Could not output all currently defined functions."

  # Include the script invocation logic
  printf "\n" && file::read_section invoke_runagfile bin/runag ||
    fail "Could not read the 'invoke_runagfile' section from bin/runag."

} >"${temp_file}" || fail "Could not write assembled content to temporary file."

# Move the newly built script to its destination with proper permissions
file::write --consume "${temp_file}" --mode 0755 dist/runag ||
  fail "Could not write the newly built script to 'dist/runag'."


# Build the dist/ssh-call script
# ------------------------------

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
  file::read_section set_shell_options bin/ssh-call && printf "\n" ||
    fail "Could not read the 'set_shell_options' section from bin/ssh-call."

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
  printf "\n" && file::read_section run_ssh_call_command bin/ssh-call ||
    fail "Could not read the 'run_ssh_call_command' section from bin/ssh-call."

} >"${temp_file}" || fail "Could not write assembled content to temporary file."

# Move the newly built script to its destination with proper permissions
file::write --consume "${temp_file}" --mode 0755 dist/ssh-call ||
  fail "Could not write the newly built script to 'dist/ssh-call'."
