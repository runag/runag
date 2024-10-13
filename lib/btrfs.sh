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

btrfs::scrub() {
  sudo btrfs scrub start "$@" || softfail || return $?
}

btrfs::scrub_status() {
  sudo btrfs scrub status -d "$@" || softfail || return $?
}

btrfs::check() {
  sudo btrfs check --readonly --progress "$@" || softfail || return $?
}
