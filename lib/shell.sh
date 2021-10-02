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

shell::display-elapsed-time() {
  echo "Elapsed time: $((SECONDS / 3600))h$(((SECONDS % 3600) / 60))m$((SECONDS % 60))s"
}
shell::install-shellrc-directory-loader() {
  local shellrcFile="$1"

  local shellrcDir="${HOME}/.shellrc.d"

  dir::make-if-not-exists "${shellrcDir}" 700 || fail

  if [ ! -f "${shellrcFile}" ]; then
    (umask 133 && touch "${shellrcFile}") || fail
  fi

  if ! grep -Fxq "# shellrc.d loader" "${shellrcFile}"; then
    cat <<SHELL >>"${shellrcFile}" || fail

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

shell::get-shellrc-filename() {
  local name="$1"

  local shellrcDir="${HOME}/.shellrc.d"

  dir::make-if-not-exists "${shellrcDir}" 700 || fail
  echo "${shellrcDir}/${name}.sh" || fail
}

shell::write-shellrc() {
  local name="$1"

  local shellrcDir="${HOME}/.shellrc.d"

  dir::make-if-not-exists "${shellrcDir}" 700 || fail
  file::write "${shellrcDir}/${name}.sh" 600 || fail
}

shell::load-shellrc() {
  local name="$1"

  local shellrcDir="${HOME}/.shellrc.d"

  . "${shellrcDir}/${name}.sh" || fail
}

shell::install-sopka-path-shellrc() {
  shell::write-shellrc "sopka-path" <<SHELL || fail
    if [ -d "\${HOME}/.sopka/bin" ]; then
      export PATH="\${HOME}/.sopka/bin:\${PATH}"
    fi
SHELL
}

shell::install-direnv-loader-shellrc() {
  shell::write-shellrc "hook-direnv" <<SHELL || fail
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

shell::install-nano-editor-shellrc() {
  shell::write-shellrc "use-nano-editor" <<SHELL || fail
    if [ -z "\${EDITOR:-}" ]; then
      if command -v nano >/dev/null; then
        export EDITOR="\$(command -v nano)"
      fi
    fi
SHELL
}
