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

if [ "${SOPKA_VERBOSE:-}" = true ]; then
  set -o xtrace
fi
set -o nounset

git::install-git || fail

git::place-up-to-date-clone "https://github.com/senotrusov/sopka.git" "${HOME}/.sopka" || fail

if [ -n "${1:-}" ] && [ "$1" != "--" ]; then
  sopka::add "$1" || fail
fi

"${HOME}/.sopka/bin/sopka" "${@:2}" || fail
