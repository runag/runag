#!/usr/bin/env bash

#  Copyright 2012-2022 Rùnag project contributors
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

# ---- install dependencies ----

ruby::install_dependencies::apt() {
  apt::install \
    build-essential `# new rails project requires some gems to be compiled` \
    libedit-dev     `# dependency to install ruby 2.7.3 using ruby-build` \
    libffi-dev      `# some gems require libffi, like fiddle-1.0.8.gem` \
    libsqlite3-dev  `# new rails project uses sqlite` \
    libssl-dev      `# dependency to install ruby 2.7.3 using ruby-build` \
    libyaml-dev     `# dependency to install ruby 3.2.2 using ruby-build` \
    zlib1g-dev      `# dependency to install ruby 2.7.3 using ruby-build` \
      || softfail || return $?
}


# ---- install by asdf ----

ruby::install_by_asdf() {
  local ruby_version="${1:-"latest"}"

  asdf::add_plugin ruby || softfail || return $?

  asdf install ruby "${ruby_version}" --verbose || softfail || return $?
}

ruby::install_by_asdf_and_set_global() {
  local ruby_version="${1:-"latest"}"

  ruby::install_by_asdf "${ruby_version}" || softfail || return $?
  asdf global ruby "${ruby_version}" || softfail || return $?
}


# ---- install by apt ----

ruby::install::apt() {
  ruby::install_dependencies::apt || softfail || return $?
  apt::install ruby-full || softfail || return $?
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
  direnv::save_variables_to_block rubygems-credentials GEM_HOST_API_KEY || softfail || return $?

  file::append_line_unless_present ".gitignore" "/.envrc" || softfail || return $?
  
  if [ -f .npmignore ]; then
    file::append_line_unless_present ".npmignore" "/.envrc" || softfail || return $?
  fi
}


# ---- configuration ----

ruby::without_docs() {
  RUBY_CONFIGURE_OPTS="--disable-install-doc" "$@" || softfail || return $?
}

ruby::dangerously_append_nodocument_to_gemrc() {
  file::append_line_unless_present --mode 0600 "${HOME}/.gemrc" "gem: --no-document" || softfail || return $?
}

ruby::disable_spring() {
  file::write --mode 0640 "${HOME}/.profile.d/disable-ruby-spring.sh" <<SHELL || softfail || return $?
$(runag::print_license)

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
    cat "${temp_file}" >&2 || softfail "Unable to read STDERR output" || { rm "${temp_file}" || softfail "Unable to remove temp file"; return 1; }
    if grep -q "^ERROR:" "${temp_file}"; then
      rm "${temp_file}" || softfail "Unable to remove temp file"
      softfail "Error found in rubygems output"
      return $?
    fi
  fi
}
