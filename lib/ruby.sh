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

ruby::apt::install() {
  apt::install \
    build-essential `# new rails project requires some gems to be compiled` \
    libsqlite3-dev `# new rails project uses sqlite` \
    ruby-full \
      || fail
  # rails also requires 'nodejs' and 'npm' apt packages, but I guess I better not to install them here
}

ruby::install-and-load-rbenv() {
  ruby::install-rbenv || fail
  ruby::load-rbenv || fail
}

ruby::install-rbenv() {
  ruby::install-rbenv-repositories || fail
  ruby::install-rbenv-shellrc || fail
}

ruby::install-rbenv-repositories() {
  local rbenvRoot="${HOME}/.rbenv"

  git::clone-or-pull "https://github.com/sstephenson/rbenv.git" "${rbenvRoot}" || fail

  mkdir -p "${rbenvRoot}/plugins" || fail
  git::clone-or-pull "https://github.com/sstephenson/ruby-build.git" "${rbenvRoot}/plugins/ruby-build" || fail
}

ruby::install-rbenv-shellrc() {
  local output="${1:-"${HOME}/.shellrc.d"}/rbenv.sh" 

  local opensslLine=""
  if [[ "$OSTYPE" =~ ^darwin ]] && command -v brew >/dev/null; then
    local opensslDir; opensslDir="$(brew --prefix openssl@1.1)" || fail
    opensslLine="export RUBY_CONFIGURE_OPTS="\${RUBY_CONFIGURE_OPTS:+"\${RUBY_CONFIGURE_OPTS} "}--with-openssl-dir=$(printf "%q" "${opensslDir}")"" || fail
  fi

  file::write "${output}" <<SHELL || fail
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
}

ruby::load-rbenv() {
  local rbenvShellrc="${HOME}/.shellrc.d/rbenv.sh"

  . "${rbenvShellrc}" || fail
  rbenv rehash || fail
}

ruby::dangerously-append-nodocument-to-gemrc() {
  file::append-line-unless-present "gem: --no-document" "${HOME}/.gemrc"
}

ruby::update-globally-installed-gems() {
  sudo gem update || fail
}
