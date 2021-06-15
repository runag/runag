#!/bin/bash

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

tailscale::install() {
  local distributorId codename

  distributorId="$(linux::get-distributor-id-lowercase)" || fail
  codename="$(lsb_release --codename --short)" || fail

  curl --fail --silent --show-error --location \
    "https://pkgs.tailscale.com/stable/${distributorId}/${codename}.gpg" | sudo apt-key add -
  test "${PIPESTATUS[*]}" = "0 0" || fail

  curl --fail --silent --show-error --location \
    "https://pkgs.tailscale.com/stable/${distributorId}/${codename}.list" | sudo tee /etc/apt/sources.list.d/tailscale.list
  test "${PIPESTATUS[*]}" = "0 0" || fail

  apt::update || fail
  apt::install tailscale || fail
}
