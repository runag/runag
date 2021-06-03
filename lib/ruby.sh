#!/usr/bin/env bash

#  Copyright 2012-2019 Stanislav Senotrusov <stan@senotrusov.com>
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

ruby::configure-gemrc() {
  local output="${HOME}/.gemrc"
  tee "${output}" <<SHELL || fail "Unable to write file: ${output} ($?)"
install: --no-document
update: --no-document
SHELL
}

ruby::install-rbenv() {
  local rbenvRoot="${HOME}/.rbenv"
  git::clone-or-pull "https://github.com/sstephenson/rbenv.git" "${rbenvRoot}" || fail
  mkdir -p "${rbenvRoot}/plugins" || fail
  git::clone-or-pull "https://github.com/sstephenson/ruby-build.git" "${rbenvRoot}/plugins/ruby-build" || fail
}

shellrcd::rbenv() {
  local output="${1:-"${HOME}/.shellrc.d"}/rbenv.sh" 

  local opensslLine=""
  if [[ "$OSTYPE" =~ ^darwin ]] && command -v brew >/dev/null; then
    local opensslDir; opensslDir="$(brew --prefix openssl@1.1)" || fail
    opensslLine="export RUBY_CONFIGURE_OPTS="\${RUBY_CONFIGURE_OPTS:+"\${RUBY_CONFIGURE_OPTS} "}--with-openssl-dir=$(printf "%q" "${opensslDir}")"" || fail
  fi

  fs::file::write "${output}" <<SHELL || fail
$(tools::licence)

if [ -d "\$HOME/.rbenv/bin" ]; then
  if ! [[ ":\$PATH:" == *":\$HOME/.rbenv/bin:"* ]]; then
    export PATH="\$HOME/.rbenv/bin:\$PATH"
  fi
fi

if command -v rbenv >/dev/null; then
  if [ -z \${RBENV_INITIALIZED+x} ]; then
    eval "\$(rbenv init -)" || { echo "Unable to init rbenv" >&2; return 1; }
    export RUBY_CONFIGURE_OPTS="\${RUBY_CONFIGURE_OPTS:+"\${RUBY_CONFIGURE_OPTS} "}--disable-install-doc"
    ${opensslLine}
    export RBENV_INITIALIZED=true
  fi
fi
SHELL

  . "${output}" || fail
}

ruby::ubuntu::install() {
  ruby::configure-gemrc || fail
  ruby::install-rbenv || fail
  shellrcd::rbenv || fail
  rbenv rehash || fail
  sudo gem update || fail
}

rails::master-key::perhaps-write-from-bitwarden-if-not-exists() {
  local bwItem="$1"

  if [ ! -f config/master.key ]; then
    if [ -n "${BITWARDEN_LOGIN:-}" ]; then
      NO_NEWLINE=true bitwarden::write-password-to-file-if-not-exists "${bwItem}" "config/master.key" || fail
    else
      echo "Please set BITWARDEN_LOGIN environment variable to get Rails master key from Bitwarden" >&2
    fi
  fi
}

rails::master-key::should-exists() {
  if [ ! -f config/master.key ]; then
    fail "config/master.key should exists"
  fi
}
