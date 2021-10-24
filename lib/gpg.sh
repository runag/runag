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

gpg::import-key-with-ultimate-ownertrust() {
  local key="$1"
  local sourcePath="$2"

  if ! gpg --list-keys "${key}" >/dev/null 2>&1; then
    file::wait-until-available "${sourcePath}" || softfail || return $?
    gpg --import "${sourcePath}" || softfail || return $?
    echo "${key}:6:" | gpg --import-ownertrust || softfail || return $?
  fi
}

gpg::decrypt-and-install-file() {
  local sourcePath="$1"
  local destPath="$2"
  local mode="${3:-"600"}"

  if [ ! -f "${destPath}" ]; then
    file::wait-until-available "${sourcePath}" || softfail || return $?
    gpg --decrypt "${sourcePath}" | file::write "${destPath}" "${mode}"
    test "${PIPESTATUS[*]}" = "0 0" || softfail || return $?
  fi
}

gpg::decrypt-and-source-script() {
  local sourcePath="$1"

  file::wait-until-available "${sourcePath}" || softfail || return $?

  local tempDir; tempDir="$(mktemp -d)" || softfail || return $?

  # I don't want to put data in file system here so I'll use fifo
  # I want sopka code to be bash-3.2 compatible so I can't use coproc
  mkfifo -m 600 "${tempDir}/fifo" || softfail || return $?

  gpg --decrypt "${sourcePath}" >"${tempDir}/fifo" &
  local gpgPid=$!

  . "${tempDir}/fifo"
  local sourceStatus=$?

  wait "${gpgPid}"
  local gpgStatus=$?

  rm "${tempDir}/fifo" || softfail || return $?
  rm -d "${tempDir}" || softfail || return $?

  test "${sourceStatus}" = "0" || softfail || return $?
  test "${gpgStatus}" = "0" || softfail || return $?
}
