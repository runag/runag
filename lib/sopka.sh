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
  export UPDATE_SECRETS=true
  "$@"
  test $? = 0 || fail "Error performing $@"
}

sopka::update-sopka-and-sopkafile() {
  if [ -d "${HOME}/.sopka/.git" ]; then
    git -C "${HOME}/.sopka" pull || fail
  fi

  if [ -d "${HOME}/.sopkafile/.git" ]; then
    git -C "${HOME}/.sopkafile" pull || fail
  fi
}
