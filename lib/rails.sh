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

rails::perhaps-write-master-key-from-bitwarden-if-not-exists() {
  local bwItem="$1"

  if [ "${UPDATE_SECRETS:-}" = "true" ] || [ ! -f config/master.key ]; then
    if [ -n "${BITWARDEN_LOGIN:-}" ]; then
      NO_NEWLINE=true bitwarden::write-password-to-file-if-not-exists "${bwItem}" "config/master.key" || fail
    else
      echo "Please set BITWARDEN_LOGIN environment variable to get Rails master key from Bitwarden" >&2
    fi
  fi
}

rails::master-key-should-exists() {
  if [ ! -f config/master.key ]; then
    fail "config/master.key should exists"
  fi
}
