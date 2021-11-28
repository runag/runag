#!/usr/bin/env bash

#  Copyright 2012-2021 Stanislav Senotrusov <stan@senotrusov.com>
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

rbenv::install-and-load-shellrc() {
  rbenv::install || softfail || return $?
  rbenv::load-shellrc || softfail || return $?
}

rbenv::install() {
  rbenv::install-repositories || softfail || return $?
  rbenv::install-shellrc || softfail || return $?
}

rbenv::install-repositories() {
  local rbenvRoot="${HOME}/.rbenv"

  git::place-up-to-date-clone "https://github.com/sstephenson/rbenv.git" "${rbenvRoot}" || softfail || return $?

  dir::make-if-not-exists "${rbenvRoot}/plugins" || softfail || return $?
  git::place-up-to-date-clone "https://github.com/sstephenson/ruby-build.git" "${rbenvRoot}/plugins/ruby-build" || softfail || return $?
}

# shellcheck disable=SC2120
rbenv::install-shellrc() {
  if [ -n "${1:-}" ]; then
    local output="$1"
  else
    local output; output="$(shellrc::get-filename "rbenv")" || softfail || return $?
  fi

  local rubyConfigureOptsLine=""
  if [ -n "${RUBY_CONFIGURE_OPTS}" ]; then
    # shellcheck disable=SC1083
    rubyConfigureOptsLine="export RUBY_CONFIGURE_OPTS="\${RUBY_CONFIGURE_OPTS:+"\${RUBY_CONFIGURE_OPTS} "}$(printf "%q" "${RUBY_CONFIGURE_OPTS}")"" || softfail || return $?
  fi

  local opensslLine=""
  if [[ "${OSTYPE}" =~ ^darwin ]] && command -v brew >/dev/null; then
    local opensslDir; opensslDir="$(brew --prefix openssl@1.1)" || softfail || return $?
    # shellcheck disable=SC1083
    opensslLine="export RUBY_CONFIGURE_OPTS="\${RUBY_CONFIGURE_OPTS:+"\${RUBY_CONFIGURE_OPTS} "}--with-openssl-dir=$(printf "%q" "${opensslDir}")"" || softfail || return $?
  fi

  file::write "${output}" 600 <<SHELL || softfail || return $?
$(sopka::print-license)

if [ -d "\${HOME}/.rbenv/bin" ]; then
  if ! [[ ":\${PATH}:" == *":\${HOME}/.rbenv/bin:"* ]]; then
    export PATH="\${HOME}/.rbenv/bin:\${PATH}"
  fi
fi

if command -v rbenv >/dev/null; then
  if [ -z \${SOPKA_RBENV_INITIALIZED+x} ]; then
    eval "\$(rbenv init -)" || { echo "Unable to init rbenv" >&2; return 1; }
    ${rubyConfigureOptsLine}
    ${opensslLine}
    export SOPKA_RBENV_INITIALIZED=true
  fi
fi
SHELL
}

rbenv::load-shellrc() {
  shellrc::load "rbenv" || softfail || return $?
}

rbenv::load-shellrc-if-exists() {
  shellrc::load-if-exists "rbenv" || softfail || return $?
}

rbenv::path-variable() {
  local userName="${1:-"${USER}"}"
  local userHome; userHome="$(linux::get-user-home "${userName}")" || softfail || return $?
  echo "${userHome}/.rbenv/shims:${userHome}/.rbenv/bin"
}

rbenv::install-ruby() {
  rbenv install --skip-existing "$@" || softfail || return $?
  rbenv rehash || softfail || return $?
}
