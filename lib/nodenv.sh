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

nodenv::install() {
  nodenv::install_repositories || softfail || return $?
  nodenv::install_shellrc || softfail || return $?
  nodenv::load_shellrc || softfail || return $?
}

nodenv::install_repositories() {
  local nodenv_root="${HOME}/.nodenv"

  git::place_up_to_date_clone "https://github.com/nodenv/nodenv.git" "${nodenv_root}" || softfail || return $?

  dir::make_if_not_exists "${nodenv_root}/plugins" || softfail || return $?
  git::place_up_to_date_clone "https://github.com/nodenv/node-build.git" "${nodenv_root}/plugins/node-build" || softfail || return $?
}

nodenv::install_shellrc() {
  if [ -n "${1:-}" ]; then
    local output="$1"
  else
    local output; output="$(shellrc::get_filename "nodenv")" || softfail || return $?
  fi

  file::write --mode 0600 "${output}" <<SHELL || softfail || return $?
$(runag::print_license)

if [ -d "\${HOME}/.nodenv/bin" ]; then
  if ! [[ ":\${PATH}:" == *":\${HOME}/.nodenv/bin:"* ]]; then
    export PATH="\${HOME}/.nodenv/bin:\${PATH}"
  fi
fi

if command -v nodenv >/dev/null; then
  if [ -z \${RUNAG_NODENV_INITIALIZED+x} ]; then
    eval "\$(nodenv init -)" || { echo "Unable to init nodenv" >&2; return 1; }
    export RUNAG_NODENV_INITIALIZED=true
  fi
fi
SHELL
}

nodenv::load_shellrc() {
  shellrc::load "nodenv" || softfail || return $?
}

nodenv::load_shellrc_if_exists() {
  shellrc::load_if_exists "nodenv" || softfail || return $?
}

nodenv::with_shellrc() {(
  nodenv::load_shellrc || softfail || return $?
  "$@"
)}

nodenv::path_variable() {
  local user_name="${1:-"${USER}"}"
  local user_home; user_home="$(linux::get_user_home "${user_name}")" || softfail || return $?
  echo "${user_home}/.nodenv/shims:${user_home}/.nodenv/bin"
}

nodenv::install_nodejs() {
  nodenv install --skip-existing "$@" || softfail || return $?
  nodenv rehash || softfail || return $?
}

nodenv::configure_mismatched_binaries_workaround() {
  # https://github.com/nodenv/nodenv/wiki/FAQ#npm-warning-about-mismatched-binaries
  npm config set scripts-prepend-node-path auto || softfail || return $?
}
