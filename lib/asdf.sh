#!/usr/bin/env bash

#  Copyright 2012-2022 Stanislav Senotrusov <stan@senotrusov.com>
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

asdf::install_dependencies_by_apt() {
  apt::install \
    curl \
    git \
      || softfail || return $?
}

asdf::install() {
  local asdf_version; asdf_version="${1:-"$(github::get_release_tag_name asdf-vm/asdf)"}" || softfail || return $?
  git::place_up_to_date_clone "https://github.com/asdf-vm/asdf.git" "${HOME}/.asdf" --branch "${asdf_version}" || softfail || return $?
  asdf::load || softfail || return $?
}

asdf::install_with_shellrc() {
  asdf::install || softfail || return $?
  asdf::install_shellrc || softfail || return $?
}

asdf::install_shellrc() {
  shellrc::write "asdf" <<SHELL || fail
$(sopka::print_license)

if [ -f "\${HOME}/.asdf/asdf.sh" ]; then
  . "\${HOME}/.asdf/asdf.sh" || { echo "Unable to load asdf" >&2; return 1; }

  if [ -n "\${ZSH_VERSION:-}" ]; then
    fpath=(\${ASDF_DIR}/completions \${fpath}) || { echo "Unable to set fpath" >&2; return 1; }
    autoload -Uz compinit || { echo "Unable to set compinit function to autoload" >&2; return 1; }
    compinit || { echo "Unable to run compinit" >&2; return 1; }

  elif [ -n "\${BASH_VERSION:-}" ]; then
    . "\${HOME}/.asdf/completions/asdf.bash" || { echo "Unable to load asdf completions" >&2; return 1; }
  fi
fi
SHELL
}

asdf::load() {
  . "${HOME}/.asdf/asdf.sh" || softfail "Unable to load asdf" || return $?
}

asdf::load_if_installed() {
  if [ -f "${HOME}/.asdf/asdf.sh" ]; then
    asdf::load || softfail || return $?
  fi
}

asdf::load_and_run() {(
  asdf::load || softfail || return $?
  "$@"
)}

asdf::path_variable() {
  local user_name="${1:-"${USER}"}"
  local user_home; user_home="$(linux::get_user_home "${user_name}")" || softfail || return $?
  echo "${user_home}/.asdf/shims:${user_home}/.asdf/bin"
}
