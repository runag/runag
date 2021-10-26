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

ruby::install-and-set-global::rbenv() {
  local rubyVersion="$1"
  ruby::install::rbenv "${rubyVersion}" || softfail || return $?
  rbenv global "${rubyVersion}" || softfail || return $?
}

# To get a version number, use: rbenv install -l
ruby::install::rbenv() {
  ruby::install-dependencies::apt || softfail || return $?
  ruby::install-and-load-rbenv || softfail || return $?
  ruby::rbenv::install "$@" || softfail || return $?
}

ruby::install-without-dependencies::rbenv() {
  ruby::install-and-load-rbenv || softfail || return $?
  ruby::rbenv::install "$@" || softfail || return $?
}

ruby::install-and-update::apt() {
  ruby::install::apt || softfail || return $?
  ruby::update-system-wide-packages || softfail || return $?
}

ruby::install::apt() {
  ruby::install-dependencies::apt || softfail || return $?
  apt::install ruby-full || softfail || return $?
}

ruby::install-dependencies::apt() {
  apt::install \
    build-essential `# new rails project requires some gems to be compiled` \
    libedit-dev `# dependency to install ruby 2.7.3 using rbenv` \
    libffi-dev `# some gems require libffi, like fiddle-1.0.8.gem` \
    libsqlite3-dev `# new rails project uses sqlite` \
    libssl-dev `# dependency to install ruby 2.7.3 using rbenv` \
    zlib1g-dev `# dependency to install ruby 2.7.3 using rbenv` \
      || softfail || return $?
}

ruby::install-and-load-rbenv() {
  ruby::install-rbenv || fail
  ruby::load-rbenv || fail
}

ruby::rbenv::install() {
  rbenv install --skip-existing "$@" || softfail || return $?

  rbenv rehash || softfail || return $?
}

ruby::install-rbenv() {
  ruby::install-rbenv-repositories || fail
  ruby::install-rbenv-shellrc || fail
}

ruby::install-rbenv-repositories() {
  local rbenvRoot="${HOME}/.rbenv"

  git::place-up-to-date-clone "https://github.com/sstephenson/rbenv.git" "${rbenvRoot}" || fail

  dir::make-if-not-exists "${rbenvRoot}/plugins" || fail
  git::place-up-to-date-clone "https://github.com/sstephenson/ruby-build.git" "${rbenvRoot}/plugins/ruby-build" || fail
}

# shellcheck disable=SC2120
ruby::install-rbenv-shellrc() {
  if [ -n "${1:-}" ]; then
    local output="$1"
  else
    local output; output="$(shellrc::get-filename "rbenv")" || fail
  fi

  local opensslLine=""
  if [[ "${OSTYPE}" =~ ^darwin ]] && command -v brew >/dev/null; then
    local opensslDir; opensslDir="$(brew --prefix openssl@1.1)" || fail
    # shellcheck disable=SC1083
    opensslLine="export RUBY_CONFIGURE_OPTS="\${RUBY_CONFIGURE_OPTS:+"\${RUBY_CONFIGURE_OPTS} "}--with-openssl-dir=$(printf "%q" "${opensslDir}")"" || fail
  fi

  file::write "${output}" 600 <<SHELL || fail
$(sopka::print-license)

if [ -d "\${HOME}/.rbenv/bin" ]; then
  if ! [[ ":\${PATH}:" == *":\${HOME}/.rbenv/bin:"* ]]; then
    export PATH="\${HOME}/.rbenv/bin:\${PATH}"
  fi
fi

if command -v rbenv >/dev/null; then
  if [ -z \${SOPKA_RBENV_INITIALIZED+x} ]; then
    eval "\$(rbenv init -)" || { echo "Unable to init rbenv" >&2; return 1; }
    export RUBY_CONFIGURE_OPTS="\${RUBY_CONFIGURE_OPTS:+"\${RUBY_CONFIGURE_OPTS} "}--disable-install-doc"
    ${opensslLine}
    export SOPKA_RBENV_INITIALIZED=true
  fi
fi
SHELL
}

ruby::load-rbenv() {
  shellrc::load "rbenv" || fail
  rbenv rehash || fail
}

ruby::dangerously-append-nodocument-to-gemrc() {
  local gemrcFile="${HOME}/.gemrc"
  (umask 177 && touch "${gemrcFile}") || fail
  file::append-line-unless-present "gem: --no-document" "${gemrcFile}" || fail
}

ruby::update-system-wide-packages() {
  sudo gem update || fail
}
