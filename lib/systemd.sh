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

systemd::write-user-unit() {
  local name="$1"

  local userUnitsDir="${HOME}/.config/systemd/user"

  dir::make-if-not-exists "${HOME}/.config" 755 || softfail || return $?
  dir::make-if-not-exists "${HOME}/.config/systemd" 700 || softfail || return $?
  dir::make-if-not-exists "${userUnitsDir}" 700 || softfail || return $?

  file::write "${userUnitsDir}/${name}" 600 || softfail || return $?
}

systemd::write-system-unit() {
  local name="$1"

  file::sudo-write /etc/systemd/system/"${name}" 644 || softfail || return $?
}
