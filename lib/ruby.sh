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

# shellcheck disable=SC2034
rubygems::direnv_credentials() {
  local GEM_HOST_API_KEY="$1"

  direnv::save_variable_block --block-name RUBYGEMS-CREDENTIALS \
    GEM_HOST_API_KEY \
    || fail

  file::append_line_unless_present --keep-permissions ".gitignore" "/.envrc" || softfail || return $?
  
  if [ -f .npmignore ]; then
    file::append_line_unless_present --keep-permissions ".npmignore" "/.envrc" || softfail || return $?
  fi
}


# ---- configuration ----

ruby::without_docs() {
  RUBY_CONFIGURE_OPTS="--disable-install-doc" "$@" || softfail || return $?
}

ruby::dangerously_append_nodocument_to_gemrc() {
  file::append_line_unless_present --keep-permissions "${HOME}/.gemrc" "gem: --no-document" || softfail || return $?
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
