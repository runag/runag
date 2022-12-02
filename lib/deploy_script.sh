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

deploy_script() {
  if [ -n "${1:-}" ]; then  
    if declare -f "deploy_script::$1" >/dev/null; then
      "deploy_script::$1" "${@:2}"
      softfail_unless_good_code $? || return $?
    else
      softfail "deploy_script: command not found: $1"
      return $?
    fi
  fi
}

deploy_script::add() {
  task::run_with_install_filter runagfile::add "$1" || softfail || return $?

  deploy_script "${@:2}"
  softfail_unless_good_code $?
}

deploy_script::run() {
  "${HOME}/.sopka/bin/sopka" "$@"
  softfail_unless_good_code $?
}

deploy_script::function_sources() {
  cat <<SHELL || softfail || return $?
$(declare -f deploy_script)
$(declare -f deploy_script::add)
$(declare -f deploy_script::run)
SHELL
}
