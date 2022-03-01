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

shellrc::install_loader() {
  local shellrc_file="$1"

  local shellrc_dir="${HOME}/.shellrc.d"

  dir::make_if_not_exists "${shellrc_dir}" 700 || fail

  if [ ! -f "${shellrc_file}" ]; then
    # ubuntu default seems to be 133 (rw-r--r--)
    # I'll try 137 (rw-r-----) to see if there are any downsides of that
    ( umask 0137 && touch "${shellrc_file}" ) || fail
  fi

  if ! grep -Fxq "# shellrc.d loader" "${shellrc_file}"; then
    cat <<SHELL >>"${shellrc_file}" || fail

# shellrc.d loader
if [ -d "\${HOME}"/.shellrc.d ]; then
  for file_bb21go6nkCN82Gk9XeY2 in "\${HOME}"/.shellrc.d/*.sh; do
    if [ -f "\${file_bb21go6nkCN82Gk9XeY2}" ]; then
      . "\${file_bb21go6nkCN82Gk9XeY2}" || { echo "Unable to load file \${file_bb21go6nkCN82Gk9XeY2} (\$?)" >&2; }
    fi
  done
  unset file_bb21go6nkCN82Gk9XeY2
fi
SHELL
  fi
}

shellrc::get_filename() {
  local name="$1"

  local shellrc_dir="${HOME}/.shellrc.d"

  dir::make_if_not_exists "${shellrc_dir}" 700 || fail
  echo "${shellrc_dir}/${name}.sh" || fail
}

shellrc::write() {
  local name="$1"

  local shellrc_dir="${HOME}/.shellrc.d"

  dir::make_if_not_exists "${shellrc_dir}" 700 || fail
  file::write "${shellrc_dir}/${name}.sh" 600 || fail
}

shellrc::load() {
  local name="$1"

  local shellrc_dir="${HOME}/.shellrc.d"

  . "${shellrc_dir}/${name}.sh" || fail
}

shellrc::load_if_exists() {
  local name="$1"

  local shellrc_dir="${HOME}/.shellrc.d"

  if [ -f "${shellrc_dir}/${name}.sh" ]; then
    . "${shellrc_dir}/${name}.sh" || fail
  fi
}

shellrc::install_sopka_path_rc() {
  shellrc::write "sopka-path" <<SHELL || fail
    if [ -d "\${HOME}/.sopka/bin" ]; then
      export PATH="\${HOME}/.sopka/bin:\${PATH}"
    fi
SHELL
}

shellrc::install_direnv_rc() {
  shellrc::write "direnv" <<SHELL || fail
    if command -v direnv >/dev/null; then
      export DIRENV_LOG_FORMAT=""
      if [ -n "\${ZSH_VERSION:-}" ]; then
        eval "\$(direnv hook zsh)" || echo "Unable to hook direnv" >&2
      elif [ -n "\${BASH_VERSION:-}" ]; then
        eval "\$(direnv hook bash)" || echo "Unable to hook direnv" >&2
      fi
    fi
SHELL
}

shellrc::install_editor_rc() {
  local editor_path="$1"
  shellrc::write "editor" <<SHELL || fail
    if [ -z "\${EDITOR:-}" ]; then
      if command -v ${editor_path} >/dev/null; then
        export EDITOR="\$(command -v ${editor_path})"
      fi
    fi
SHELL
}
