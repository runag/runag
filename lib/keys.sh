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

keys::ensure-key-is-available() {
  local keyPath="$1"
  if [ ! -f "${keyPath}" ]; then
    echo "File not found: '${keyPath}'. Please connect external media if necessary and press ENTER" >&2
    read -s || fail
  fi
  if [ ! -f "${keyPath}" ]; then
    fail "File still not found: ${keyPath}"
  fi
}

keys::install-gpg-key() {
  local key="$1"
  local sourcePath="$2"

  if ! gpg --list-keys "${key}" >/dev/null 2>&1; then
    keys::ensure-key-is-available "${sourcePath}" || fail
    gpg --import "${sourcePath}" || fail
    echo "${key}:6:" | gpg --import-ownertrust || fail
  fi
}

keys::install-decrypted-file() {
  local sourcePath="$1"
  local destPath="$2"
  local setUmask="${3:-}"

  if [ ! -f "${destPath}" ]; then
    keys::ensure-key-is-available "${sourcePath}" || fail
    gpg --decrypt "${sourcePath}" | file::write "${destPath}" "${setUmask}"
    test "${PIPESTATUS[*]}" = "0 0" || fail
  fi
}
