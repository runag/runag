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

deploy-lib::shellrcd::install() {
  if [ ! -d "${HOME}/.shellrc.d" ]; then
    mkdir -p "${HOME}/.shellrc.d" || fail "Unable to create the directory: ${HOME}/.shellrc.d"
  fi

  deploy-lib::shellrcd::add-loader "${HOME}/.bashrc" || fail
  deploy-lib::shellrcd::add-loader "${HOME}/.zshrc" || fail
}

deploy-lib::shellrcd::add-loader() {
  local shellrcFile="$1"

  if [ ! -f "${shellrcFile}" ]; then
    touch "${shellrcFile}" || fail
  fi

  if grep --quiet "^# shellrc.d loader" "${shellrcFile}"; then
    echo "shellrc.d loader already present"
  else
tee -a "${shellrcFile}" <<SHELL || fail "Unable to append to the file: ${shellrcFile}"

# shellrc.d loader
if [ -d "\${HOME}/.shellrc.d" ]; then
  for file_bb21go6nkCN82Gk9XeY2 in "\${HOME}/.shellrc.d"/*.sh; do
    if [ -f "\${file_bb21go6nkCN82Gk9XeY2}" ]; then
      . "\${file_bb21go6nkCN82Gk9XeY2}" || { echo "Unable to load file \${file_bb21go6nkCN82Gk9XeY2} (\$?)"; }
    fi
  done
  unset file_bb21go6nkCN82Gk9XeY2
fi
SHELL
  fi
}
