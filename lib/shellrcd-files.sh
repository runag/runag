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

shellrcd::use-nano-editor() {
  fs::file::write "${HOME}/.shellrc.d/use-nano-editor.sh" <<SHELL || fail
    if [ -z "\${EDITOR:-}" ]; then
      if command -v nano >/dev/null; then
        export EDITOR="\$(command -v nano)"
      fi
    fi
SHELL
}

shellrcd::sopka-path() {
  fs::file::write "${HOME}/.shellrc.d/sopka-path.sh" <<SHELL || fail
    if [ -d "\${HOME}/.sopka" ]; then
      export PATH="\${HOME}/.sopka/bin:\$PATH"
    fi
SHELL
}

shellrcd::hook-direnv() {
  fs::file::write "${HOME}/.shellrc.d/hook-direnv.sh" <<SHELL || fail
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
