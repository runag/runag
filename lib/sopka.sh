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

sopka::with-update-secrets() {
  export SOPKA_UPDATE_SECRETS=true
  "$@"
}

sopka::with-verbose-tasks() {
  export SOPKA_VERBOSE_TASKS=true
  "$@"
}

sopka::update() {
  if [ -d "${HOME}/.sopka/.git" ]; then
    git -C "${HOME}/.sopka" pull || softfail || return

    local fileFolder; for fileFolder in "${HOME}"/.sopka/sopkafiles/*; do
      if [ -d "${fileFolder}/.git" ]; then
        git -C "${fileFolder}" pull || softfail || return
      fi
    done
  fi
}

sopka::print-license() {
  cat <<EOT
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
EOT
}

sopka::add-sopkafile() {
  local packageId="$1"
  local dest; dest="$(echo "${packageId}" | tr "/" "-")" || softfail || return
  git::place-up-to-date-clone "https://github.com/${packageId}.git" "${HOME}/.sopka/sopkafiles/github-${dest}" || softfail || return
}

# Find and load sopkafile.
#
# Possible locations are:
#
# ./sopkafile
# ./sopkafile/index.sh
#
# ~/.sopkafile
# ~/.sopkafile/index.sh
#
# ~/.sopka/sopkafiles/*/index.sh
#
sopka::load-sopkafile() {
  if [ -f "./sopkafile" ]; then
    . "./sopkafile"
    softfail-unless-good "Unable to load './sopkafile' ($?)" $?
    return

  elif [ -f "./sopkafile/index.sh" ]; then
    . "./sopkafile/index.sh"
    softfail-unless-good "Unable to load './sopkafile/index.sh' ($?)" $?
    return

  elif [ -n "${HOME:-}" ] && [ -f "${HOME:-}/.sopkafile" ]; then
    . "${HOME:-}/.sopkafile"
    softfail-unless-good "Unable to load '${HOME:-}/.sopkafile' ($?)" $?
    return

  elif [ -n "${HOME:-}" ] && [ -f "${HOME:-}/.sopkafile/index.sh" ]; then
    . "${HOME:-}/.sopkafile/index.sh"
    softfail-unless-good "Unable to load '${HOME:-}/.sopkafile/index.sh' ($?)" $?
    return

  else
    local fileFound=false
    local filePath; for filePath in "${HOME}"/.sopka/sopkafiles/*/index.sh; do
      if [ -f "${filePath}" ]; then
        . "${filePath}"
        softfail-unless-good "Unable to load '${filePath}' ($?)" $? || return
        fileFound=true
      fi
    done
    if [ "${fileFound}" = false ]; then
      log::error "Unable to find sopkafile"
      return 1
    fi
  fi
}
