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

windows::run-admin-powershell-script() {
  echo "Running $1 script..."
  powershell -Command "Start-Process powershell \"-ExecutionPolicy Bypass -NoProfile -NoExit -Command $1\" -Wait -Verb RunAs" || fail
  # I have no idea on how to obtain the exit status here, so for now I just choose to put -NoExit and let the user decide
  echo "Press ENTER if it went ok"
  read
}

windows::enable-ssh-agent() {
  windows::run-admin-powershell-script "${SOPKA_SRC_WIN_DIR}\lib\windows\enable-ssh-agent.ps1" || fail
}

windows::install-chocolatey() {
  windows::run-admin-powershell-script "${SOPKA_SRC_WIN_DIR}\lib\windows\chocolatey-install.ps1" || fail
}

windows::chocolatey::upgrade-all() {
  windows::run-admin-powershell-script "${SOPKA_SRC_WIN_DIR}\lib\windows\chocolatey-upgrade-all.ps1" || fail
}

windows::is-bare-metal() {
  ! powershell -Command "Get-WmiObject Win32_computerSystem" | grep --quiet --fixed-strings "VMware"
}
