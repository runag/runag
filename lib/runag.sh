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

# ### `runag::mini_library`
#
# This function generates a minimal bash script preamble used for producing derivative scripts from Runag code. 
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
  printf "#!/usr/bin/env bash\n\n" || softfail "Failed to print the shebang line." || return $?

  # Print the license information.
  # shellcheck disable=SC2015
  runag::print_license && printf "\n" || softfail "Error printing license information." || return $?

  # If the argument is '--nounset', set the nounset option to treat unset variables as errors.
  if [ "${1:-}" = "--nounset" ]; then
    printf "set -o nounset\n\n" || softfail "Failed to print 'nounset' option." || return $?
  fi

  # Output the code for the functions
  declare -f fail || softfail "The 'fail' function is not defined." || return $?
  declare -f softfail || softfail "The 'softfail' function is not defined." || return $?
  declare -f dir::ensure_exists || softfail "The 'dir::ensure_exists' function is not defined." || return $?
  declare -f file::write || softfail "The 'file::write' function is not defined." || return $?
}

# ### `runag::print_license`
#
# This function prints the copyright and licensing information for the Runag project.
# It includes the project's copyright notice and specifies that the project is licensed under the Apache License, Version 2.0.
#
runag::print_license() {
  cat <<SHELL
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
SHELL
}

# ### `runag::extend_package_list::debian`
#
# This function populates the `package_list` array with the essential dependencies required 
# for running Runag on systems using `apt` (Debian GNU/Linux) as their package manager.
#
# #### Usage:
# 
# runag::extend_package_list::debian
#
# #### Example:
# 
# ```bash
# package_list=()
# runag::extend_package_list::debian
# echo "${package_list[@]}"
# ```
#
runag::extend_package_list::debian() {
  package_list+=(
    apt-transport-https  # Enables support for HTTPS in `apt`.
    curl                 # Command-line tool for transferring data using various protocols.
    git                  # Version control system for tracking changes in source code.
    gpg                  # GNU Privacy Guard for encryption and signing.
    jq                   # Command-line JSON processor.
    pass                 # Standard Unix password manager.
    xxd                  # Command-line utility to create a hexdump or reverse it.
  )
}

# ### `runag::extend_package_list::arch`
#
# This function populates the `package_list` array with the essential dependencies required 
# for running Runag on systems using `pacman` (Arch Linux) as their package manager.
#
# #### Usage:
# 
# runag::extend_package_list::arch
#
# #### Example:
# 
# ```bash
# package_list=()
# runag::extend_package_list::arch
# echo "${package_list[@]}"
# ```
#
runag::extend_package_list::arch() {
  package_list+=(
    curl     # Command-line tool for transferring data using various protocols.
    git      # Version control system for tracking changes in source code.
    gnupg    # GNU Privacy Guard for encryption and signing.
    jq       # Command-line JSON processor.
    pass     # Standard Unix password manager.
    tinyxxd  # Lightweight version of the xxd utility for hexdump operations.
  )
}
