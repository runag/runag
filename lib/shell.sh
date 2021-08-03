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

shell::fail-unless-command-is-found() {
  for cmd in "$@"; do
    command -v "${cmd}" >/dev/null || fail "${cmd} command is not found"
  done
}

shell::install-shellrc-directory-loader() {
  local shellrcFile="$1"
  local rcDir="${HOME}/.shellrc.d"

  if [ ! -d "${rcDir}" ]; then
    mkdir -p "${rcDir}" || fail "Unable to create the directory: ${rcDir}"
  fi

  if [ ! -f "${shellrcFile}" ]; then
    touch "${shellrcFile}" || fail
  fi

  if ! grep --quiet "^# shellrc\\.d loader" "${shellrcFile}"; then
    cat <<SHELL >>"${shellrcFile}" || fail "Unable to append to the file: ${shellrcFile}"

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

shell::install-sopka-path-shellrc() {
  file::write "${HOME}/.shellrc.d/sopka-path.sh" <<SHELL || fail
    if [ -d "\${HOME}/.sopka" ]; then
      export PATH="\${HOME}/.sopka/bin:\${PATH}"
    fi
SHELL
}

shell::install-direnv-loader-shellrc() {
  file::write "${HOME}/.shellrc.d/hook-direnv.sh" <<SHELL || fail
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
  file::write "${HOME}/.shellrc.d/use-nano-editor.sh" <<SHELL || fail
    if [ -z "\${EDITOR:-}" ]; then
      if command -v nano >/dev/null; then
        export EDITOR="\$(command -v nano)"
      fi
    fi
SHELL
}
