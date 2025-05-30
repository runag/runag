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

# https://github.com/rbenv/ruby-build/wiki#suggested-build-environment

ruby::extend_package_list::debian() {
  package_list+=(
    build-essential # new rails project requires some gems to be compiled
    libedit-dev     # ruby install via ruby-build (for ruby versions: 2.7.3)
    libffi-dev      # some gems require libffi (fiddle-1.0.8.gem)
    libsqlite3-dev  # new rails project uses sqlite
    libssl-dev      # ruby install via ruby-build (for ruby versions: 2.7.3)
    libyaml-dev     # ruby install via ruby-build (for ruby versions: 3.2.2)
    zlib1g-dev      # ruby install via ruby-build (for ruby versions: 2.7.3)
  )
}

ruby::extend_package_list::arch() {
  package_list+=(
    base-devel # ruby install via ruby-build
    libffi     # ruby install via ruby-build
    libyaml    # ruby install via ruby-build
    openssl    # ruby install via ruby-build
    rust       # ruby install via ruby-build
    sqlite     # new rails project uses sqlite
    zlib       # ruby install via ruby-build
  )
}


# ---- credentials ----

rubygems::credentials::exists() {
  local file_path="${HOME}/.gem/credentials"
  test -s "${file_path}"
}

rubygems::credentials() {
  local api_key="$1"
  
  local file_path="${HOME}/.gem/credentials"

  file::write --mode 0600 "${file_path}" <<YAML || softfail "Unable to write secret to file" || return $?
---
:rubygems_api_key: ${api_key}
YAML
}

# ## `rubygems::direnv_credentials`
#
# Saves the RubyGems API key to `.envrc` so that direnv can automatically
# load it as an environment variable in the current directory.
#
# ### Usage
#
# rubygems::direnv_credentials <API_KEY>
#
# * `<API_KEY>`: The RubyGems API key to be stored in `.envrc` as `GEM_HOST_API_KEY`.
#
rubygems::direnv_credentials() {
  # shellcheck disable=SC2034
  local GEM_HOST_API_KEY="$1"
  local envrc_path=".envrc"

  # Ensure .envrc is allowed by direnv
  direnv::is_allowed "${envrc_path}" || softfail "'.envrc' is not allowed by direnv" || return $?

  # Write the credentials to .envrc with a section label
  file::write --user-only --capture --section "RUBYGEMS-CREDENTIALS" "${envrc_path}" shell::emit_exports \
    GEM_HOST_API_KEY \
      || softfail "Failed to write RubyGems credentials to .envrc" || return $?

  # Re-authorize .envrc with direnv
  direnv allow "${envrc_path}" || softfail "Failed to allow '.envrc' via direnv" || return $?

  # Ensure .envrc is ignored by Git
  file::write --append-line-unless-present ".gitignore" "/.envrc" || softfail || return $?

  # Also ignore .envrc in npm packages, if applicable
  if [ -f .npmignore ]; then
    file::write --append-line-unless-present ".npmignore" "/.envrc" || softfail || return $?
  fi
}

# ---- configuration ----

ruby::without_docs() {
  RUBY_CONFIGURE_OPTS="--disable-install-doc" "$@" || softfail || return $?
}

ruby::dangerously_append_nodocument_to_gemrc() {
  file::write --append-line-unless-present "${HOME}/.gemrc" "gem: --no-document" || softfail || return $?
}

ruby::install_disable_spring_shellfile() {
  local license_text; license_text="$(runag::print_license)" || softfail || return $?

  shellfile::write "profile/ruby-disable-spring" <<SHELL || softfail || return $?
${license_text}

export DISABLE_SPRING=true
SHELL
}


# ---- fail detector ----

ruby::gem() {
  local exit_status
  local temp_file; temp_file="$(mktemp)" || softfail || return $?

  gem "$@" 2>"${temp_file}"
  exit_status=$?

  if [ "${exit_status}" != 0 ]; then
    rm "${temp_file}" || softfail "Unable to remove temp file"
    return "${exit_status}"
  fi

  if [ -s "${temp_file}" ]; then
    cat "${temp_file}" >&2 || softfail "Unable to read STDERR output from temp file: ${temp_file}" || return $?
    if grep -q "^ERROR:" "${temp_file}"; then
      rm "${temp_file}" || softfail "Unable to remove temp file"
      softfail "Error found in rubygems output"
      return $?
    fi
  fi
}
