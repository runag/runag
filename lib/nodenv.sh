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

nodenv::install-and-load-shellrc() {
  nodenv::install || softfail || return $?
  nodenv::load-shellrc || softfail || return $?
}

nodenv::install() {
  nodenv::install-repositories || softfail || return $?
  nodenv::install-shellrc || softfail || return $?
}

nodenv::install-repositories() {
  local nodenvRoot="${HOME}/.nodenv"

  git::place-up-to-date-clone "https://github.com/nodenv/nodenv.git" "${nodenvRoot}" || softfail || return $?

  dir::make-if-not-exists "${nodenvRoot}/plugins" || softfail || return $?
  git::place-up-to-date-clone "https://github.com/nodenv/node-build.git" "${nodenvRoot}/plugins/node-build" || softfail || return $?
}

nodenv::install-shellrc() {
  if [ -n "${1:-}" ]; then
    local output="$1"
  else
    local output; output="$(shellrc::get-filename "nodenv")" || softfail || return $?
  fi

  file::write "${output}" 600 <<SHELL || softfail || return $?
$(sopka::print-license)

if [ -d "\${HOME}/.nodenv/bin" ]; then
  if ! [[ ":\${PATH}:" == *":\${HOME}/.nodenv/bin:"* ]]; then
    export PATH="\${HOME}/.nodenv/bin:\${PATH}"
  fi
fi

if command -v nodenv >/dev/null; then
  if [ -z \${SOPKA_NODENV_INITIALIZED+x} ]; then
    eval "\$(nodenv init -)" || { echo "Unable to init nodenv" >&2; return 1; }
    export SOPKA_NODENV_INITIALIZED=true
  fi
fi
SHELL
}

nodenv::load-shellrc() {
  shellrc::load "nodenv" || softfail || return $?
}

nodenv::load-shellrc-if-exists() {
  shellrc::load-if-exists "nodenv" || softfail || return $?
}

nodenv::with-shellrc() {(
  nodenv::load-shellrc || softfail || return $?
  "$@"
)}

nodenv::path-variable() {
  local userName="${1:-"${USER}"}"
  local userHome; userHome="$(linux::get-user-home "${userName}")" || softfail || return $?
  echo "${userHome}/.nodenv/shims:${userHome}/.nodenv/bin"
}

nodenv::install-nodejs() {
  nodenv install --skip-existing "$@" || softfail || return $?
  nodenv rehash || softfail || return $?
}

nodenv::configure-mismatched-binaries-workaround() {
  # https://github.com/nodenv/nodenv/wiki/FAQ#npm-warning-about-mismatched-binaries
  npm config set scripts-prepend-node-path auto || softfail || return $?
}
