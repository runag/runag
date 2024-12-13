#!/usr/bin/env bash

#  Copyright 2012-2024 Rùnag project contributors
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

tailscale::add_apt_source() (
  # Load operating system identification data
  . /etc/os-release || softfail || return $?

  apt::add_source_with_key "tailscale" \
    "https://pkgs.tailscale.com/stable/${ID} ${VERSION_CODENAME} main" \
    "https://pkgs.tailscale.com/stable/${ID}/${VERSION_CODENAME}.gpg" || softfail || return $?
)

tailscale::is_logged_in() {
  # this function is intent to use fail (and not softfail) in case of errors
  local backend_state; backend_state="$(tailscale status --json | jq --raw-output --exit-status .BackendState; test "${PIPESTATUS[*]}" = "0 0")" || fail "Unable to obtain tailscale status" # no softfail here!

  if [ "${backend_state}" = "NeedsLogin" ]; then
    return 1
  else
    return 0
  fi
}
