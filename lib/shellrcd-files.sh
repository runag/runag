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

deploy-lib::shellrcd::stan-computer-deploy-path() {
  local output="${HOME}/.shellrc.d/stan-computer-deploy-path.sh"
  tee "${output}" <<SHELL || fail "Unable to write file: ${output} ($?)"
    export PATH="${MY_COMPUTER_DEPLOY_DIR}/bin:\$PATH"
SHELL
}

deploy-lib::shellrcd::use-nano-editor() {
  local output="${HOME}/.shellrc.d/use-nano-editor.sh"
  local nanoPath; nanoPath="$(command -v nano)" || fail
  tee "${output}" <<SHELL || fail "Unable to write file: ${output} ($?)"
  export EDITOR="${nanoPath}"
SHELL
}

deploy-lib::shellrcd::hook-direnv() {
  local output="${HOME}/.shellrc.d/hook-direnv.sh"
  tee "${output}" <<SHELL || fail "Unable to write file: ${output} ($?)"
  export DIRENV_LOG_FORMAT=""
  if [ "\$SHELL" = "/bin/zsh" ]; then
    eval "\$(direnv hook zsh)" || echo "Unable to hook direnv" >&2
  elif [ "\$SHELL" = "/bin/bash" ]; then
    eval "\$(direnv hook bash)" || echo "Unable to hook direnv" >&2
  fi
SHELL
}
