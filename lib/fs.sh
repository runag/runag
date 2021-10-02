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

dir::make-if-not-exists() {
  local dirPath="$1"
  local mode="${2:-}"

  if ! mkdir ${mode:+-m "${mode}"} "${dirPath}" 2>/dev/null; then
    test -d "${dirPath}" || fail "Unable to create directory, maybe file already exists: ${dirPath}"
  fi
}

dir::make-if-not-exists-but-chmod-anyway() {
  local dirPath="$1"
  local mode="${2:-}"

  if ! mkdir ${mode:+-m "${mode}"} "${dirPath}" 2>/dev/null; then
    test -d "${dirPath}" || fail "Unable to create directory, maybe file already exists: ${dirPath}"
    chmod "${mode}" "${dirPath}" || fail
  fi
}

dir::remove-if-exists-and-empty() {
  local dirPath="$1"
  rmdir "${dirPath}" 2>/dev/null || true
}

file::sudo-write() {
  local dest="$1"
  local mode="${2:-}"
  local owner="${3:-}"
  local group="${4:-}"

  if [ -n "${mode}" ] || [ -n "${owner}" ] || [ -n "${group}" ]; then
    # I want to create a file with the right mode right away
    # the use of "install" command performs that, at least on linux and macos
    # it creates a file with the mode 600, which is good, and then it changes the mode to the one provided in the argument
    # it's probably better to make it different, like calculate umask and then touch, but I don't have time to think about that right now
    sudo install ${mode:+-m "${mode}"} ${owner:+-o "${owner}"} ${group:+-g "${group}"} /dev/null "${dest}" || fail
  fi

  cat | sudo tee "${dest}" >/dev/null
  test "${PIPESTATUS[*]}" = "0 0" || fail
}

file::write() {
  local dest="$1"
  local mode="${2:-}"

  if [ -n "${mode}" ]; then
    # I want to create a file with the right mode right away
    # the use of "install" command performs that, at least on linux and macos
    # it creates a file with the mode 600, which is good, and then it changes the mode to the one provided in the argument
    # it's probably better to make it different, like calculate umask and then touch, but I don't have time to think about that right now
    install -m "${mode}" /dev/null "${dest}" || fail
  fi

  cat >"${dest}" || fail
}

file::append-line-unless-present() {
  local string="$1"
  local file="$2"

  if ! test -f "${file}"; then
    fail "File not found: ${file}"
  fi

  if ! grep -qFx "${string}" "${file}"; then
    echo "${string}" | tee -a "${file}" >/dev/null || fail
  fi
}

file::sudo-append-line-unless-present() {
  local string="$1"
  local file="$2"

  if ! sudo test -f "${file}"; then
    fail "File not found: ${file}"
  fi
    
  if ! sudo grep -qFx "${string}" "${file}"; then
    echo "${string}" | sudo tee -a "${file}" >/dev/null || fail
  fi
}

mount::ask-for-mount() {
  local mountpoint="$1"

  if ! findmnt --mountpoint "${mountpoint}" >/dev/null; then
    echo "Please attach filesystem to ${mountpoint} and press ENTER"
    read -rs || fail
  fi

  findmnt --mountpoint "${mountpoint}" >/dev/null || fail "Unable to find filesystem at ${mountpoint}"
}

path::convert-msys-to-windows() {
  echo "$1" | sed "s/^\\/\\([[:alpha:]]\\)\\//\\1:\\//" | sed "s/\\//\\\\/g"
  test "${PIPESTATUS[*]}" = "0 0 0" || fail
}  
