#!/usr/bin/env bash

#  Copyright 2012-2019 Stanislav Senotrusov <stan@senotrusov.com>
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

windows::enable-ssh-agent() {
  windows::run-admin-powershell-script "${SOPKA_SRC_WIN_DIR}/lib/windows/enable-ssh-agent.ps1" || fail
}

windows::run-admin-powershell-script() {
  powershell -Command "Start-Process powershell \"-ExecutionPolicy Bypass -NoProfile -Command $1\" -Verb RunAs" || fail
}
