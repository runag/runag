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

# ## `direnv::is_allowed`
#
# Checks whether the specified `.envrc` file is explicitly allowed by direnv.
#
# ### Usage
#
# direnv::is_allowed [<envrc_path>]
#
# * `<envrc_path>`: Path to the `.envrc` file to check (defaults to `.envrc` in the current directory)
#
# Returns successfully if the file is currently allowed.
# Otherwise, it returns a non-zero exit status.
#
direnv::is_allowed() (
  local envrc_path="${1:-".envrc"}"
  local envrc_dir envrc_basename envrc_realpath status_output

  # Extract the directory and filename components
  envrc_dir="$(dirname "${envrc_path}")" || softfail "Failed to get directory from path" || return $?
  envrc_basename="$(basename "${envrc_path}")" || softfail "Failed to get filename from path" || return $?

  cd "${envrc_dir}" || softfail "Failed to change to directory: ${envrc_dir}" || return $?

  envrc_realpath="${PWD}/${envrc_basename}"

  # Fetch direnv status as JSON
  status_output="$(direnv status --json)" || softfail "Failed to get direnv status" || return $?

  # Use jq to check whether the envrc file is currently allowed
  # jq with --exit-status returns 0 if the result is not false or null
  <<<"${status_output}" jq --raw-output --exit-status --arg envrc_realpath "${envrc_realpath}" \
    '((.state | has("foundRC")) and ((.state.foundRC == null) or (.state.foundRC.allowed == 0 and .state.foundRC.path == $envrc_realpath)))' >/dev/null
)
