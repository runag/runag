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
  if [ -t 1 ]; then
    log::notice "SOPKA_UPDATE_SECRETS flag is set" || fail
  fi
  export SOPKA_UPDATE_SECRETS=true
  "$@"
}

sopka::with-verbose-tasks() {
  if [ -t 1 ]; then
    log::notice "SOPKA_TASK_VERBOSE flag is set" || fail
  fi
  export SOPKA_TASK_VERBOSE=true
  "$@"
}

sopka::linux::run-benchmark() {
  benchmark::run || softfail || return $?
}

sopka::linux::display-if-restart-required() {
  linux::display-if-restart-required || softfail || return $?
}

sopka::linux::dangerously-set-hostname() {
  echo "Please keep in mind that the script to change hostname is not perfect, please take time to review the script and it's results"
  echo "Please enter new hostname:"
  
  local hostname; IFS="" read -r hostname || softfail || return $?

  linux::dangerously-set-hostname "${hostname}" || softfail || return $?

  log::success "Done" || softfail || return $?
}

sopka::install-as-repository-clone() {
  git::place-up-to-date-clone "https://github.com/senotrusov/sopka.git" "${HOME}/.sopka" || softfail || return $?
}

sopka::update() {
  if [ -d "${HOME}/.sopka/.git" ]; then
    git -C "${HOME}/.sopka" pull || softfail || return $?

    local sopkafileDir; for sopkafileDir in "${HOME}"/.sopka/sopkafiles/*; do
      if [ -d "${sopkafileDir}/.git" ]; then
        git -C "${sopkafileDir}" pull || softfail || return $?
      fi
    done
  fi
}

sopka::print-license() {
  cat <<SHELL
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
SHELL
}

sopka::add-sopkafile() {
  local packageId="$1"
  local dest; dest="$(echo "${packageId}" | tr "/" "-")" || softfail || return $?
  git::place-up-to-date-clone "https://github.com/${packageId}.git" "${HOME}/.sopka/sopkafiles/github-${dest}" || softfail || return $?
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
  if [ -f "./sopkafile.sh" ]; then
    . "./sopkafile.sh"
    softfail-unless-good "Unable to load './sopkafile.sh' ($?)" $?
    return $?

  elif [ -f "./sopkafile/index.sh" ]; then
    . "./sopkafile/index.sh"
    softfail-unless-good "Unable to load './sopkafile/index.sh' ($?)" $?
    return $?

  elif [ -n "${HOME:-}" ] && [ -f "${HOME:-}/.sopkafile.sh" ]; then
    . "${HOME:-}/.sopkafile.sh"
    softfail-unless-good "Unable to load '${HOME:-}/.sopkafile.sh' ($?)" $?
    return $?

  elif [ -n "${HOME:-}" ] && [ -f "${HOME:-}/.sopkafile/index.sh" ]; then
    . "${HOME:-}/.sopkafile/index.sh"
    softfail-unless-good "Unable to load '${HOME:-}/.sopkafile/index.sh' ($?)" $?
    return $?

  else
    local filePath; for filePath in "${HOME}"/.sopka/sopkafiles/*/index.sh; do
      if [ -f "${filePath}" ]; then
        . "${filePath}"
        softfail-unless-good "Unable to load '${filePath}' ($?)" $? || return $?
      fi
    done
  fi
}
