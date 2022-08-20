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

rbenv::install() {
  rbenv::install_repositories || softfail || return $?
  rbenv::install_shellrc || softfail || return $?
  rbenv::load_shellrc || softfail || return $?
}

rbenv::install_repositories() {
  local rbenv_root="${HOME}/.rbenv"

  git::place_up_to_date_clone "https://github.com/sstephenson/rbenv.git" "${rbenv_root}" || softfail || return $?

  dir::make_if_not_exists "${rbenv_root}/plugins" || softfail || return $?
  git::place_up_to_date_clone "https://github.com/sstephenson/ruby-build.git" "${rbenv_root}/plugins/ruby-build" || softfail || return $?
}

# shellcheck disable=SC2120
rbenv::install_shellrc() {
  if [ -n "${1:-}" ]; then
    local output="$1"
  else
    local output; output="$(shellrc::get_filename "rbenv")" || softfail || return $?
  fi

  local ruby_configure_opts_line=""
  if [ -n "${RUBY_CONFIGURE_OPTS:-}" ]; then
    # shellcheck disable=SC1083
    ruby_configure_opts_line="export RUBY_CONFIGURE_OPTS="\${RUBY_CONFIGURE_OPTS:+"\${RUBY_CONFIGURE_OPTS} "}$(printf "%q" "${RUBY_CONFIGURE_OPTS}")"" || softfail || return $?
  fi

  local openssl_line=""
  if [[ "${OSTYPE}" =~ ^darwin ]] && command -v brew >/dev/null; then
    local openssl_dir; openssl_dir="$(brew --prefix openssl@1.1)" || softfail || return $?
    # shellcheck disable=SC1083
    openssl_line="export RUBY_CONFIGURE_OPTS="\${RUBY_CONFIGURE_OPTS:+"\${RUBY_CONFIGURE_OPTS} "}--with-openssl-dir=$(printf "%q" "${openssl_dir}")"" || softfail || return $?
  fi

  file::write "${output}" 600 <<SHELL || softfail || return $?
$(sopka::print_license)

if [ -d "\${HOME}/.rbenv/bin" ]; then
  if ! [[ ":\${PATH}:" == *":\${HOME}/.rbenv/bin:"* ]]; then
    export PATH="\${HOME}/.rbenv/bin:\${PATH}"
  fi
fi

if command -v rbenv >/dev/null; then
  if [ -z \${SOPKA_RBENV_INITIALIZED+x} ]; then
    eval "\$(rbenv init -)" || { echo "Unable to init rbenv" >&2; return 1; }
    ${ruby_configure_opts_line}
    ${openssl_line}
    export SOPKA_RBENV_INITIALIZED=true
  fi
fi
SHELL
}

rbenv::load_shellrc() {
  shellrc::load "rbenv" || softfail || return $?
}

rbenv::load_shellrc_if_exists() {
  shellrc::load_if_exists "rbenv" || softfail || return $?
}

rbenv::with_shellrc() {(
  rbenv::load_shellrc || softfail || return $?
  "$@"
)}

rbenv::path_variable() {
  local user_name="${1:-"${USER}"}"
  local user_home; user_home="$(linux::get_user_home "${user_name}")" || softfail || return $?
  echo "${user_home}/.rbenv/shims:${user_home}/.rbenv/bin"
}

rbenv::install_ruby() {
  rbenv install --skip-existing "$@" || softfail || return $?
  rbenv rehash || softfail || return $?
}
