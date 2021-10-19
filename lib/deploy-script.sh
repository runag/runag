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

deploy-script() {
  if [ -n "${1:-}" ]; then  
    if declare -f "deploy-script::$1" >/dev/null; then
      "deploy-script::$1" "${@:2}"
      softfail-unless-good-code $? || return $?
    else
      softfail "Sopka deploy-script: command not found: $1"
      return $?
    fi
  fi
}

deploy-script::add() {
  task::run sopka::add-sopkafile "$1" || softfail || return $?

  deploy-script "${@:2}"
  softfail-unless-good-code $?
}

deploy-script::run() {
  "${HOME}/.sopka/bin/sopka" "$@"
  softfail-unless-good-code $?
}
