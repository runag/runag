#!/usr/bin/env bash

#  Copyright 2012-2025 Runag project contributors
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

ubuntu::pro::is_attached() {
  pro status --format json | jq --raw-output --exit-status '.attached == true' >/dev/null
}

ubuntu::pro::available() (
  # Load operating system identification data
  # shellcheck disable=SC1091
  . /etc/os-release || softfail || return $?
  
  test "${ID:-}" = ubuntu && command -v pro >/dev/null
)
