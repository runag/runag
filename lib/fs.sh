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

  if [ ! -d "${dirPath}" ]; then
    mkdir "${dirPath}" || fail
  fi

  if [ -n "${mode}" ]; then
    chmod "${mode}" "${dirPath}" || fail
  fi
}

file::sudo-write() {
  local dest="$1"
  local mode="${2:-}"
  local ownerAndMaybeGroup="${3:-}"

  sudo touch "${dest}" || fail

  if [ -n "${mode}" ]; then
    sudo chmod "${mode}" "${dest}" || fail
  fi

  if [ -n "${ownerAndMaybeGroup}" ]; then
    sudo chown "${ownerAndMaybeGroup}" "${dest}" || fail
  fi

  cat | sudo tee "${dest}" >/dev/null
  test "${PIPESTATUS[*]}" = "0 0" || fail
}

file::write() {
  local dest="$1"
  local umaskValue="${2:-}"

  local dirName; dirName="$(dirname "${dest}")" || fail
  
  (
    if [ -n "${umaskValue}" ]; then
      umask "${umaskValue}" || fail
    fi

    mkdir -p "${dirName}" || fail

    cat | tee "${dest}" >/dev/null
    test "${PIPESTATUS[*]}" = "0 0" || fail
  ) || fail
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

mount::cifs::credentials::exists() {
  local credentialsFile="$1"
  test -f "${credentialsFile}"
}

mount::cifs::credentials::save() {
  local cifsUsername="$1"
  local cifsPassword="$2"
  local credentialsFile="$3"
  local umaskValue="${4:-"077"}"

  printf "username=%s\npassword=%s\n" "${cifsUsername}" "${cifsPassword}" | file::write "${credentialsFile}" "${umaskValue}"
  test "${PIPESTATUS[*]}" = "0 0" || fail
}

mount::cifs() {
  local serverPath="$1"
  local mountPoint="$2"
  local credentialsFile="$4"

  mkdir -p "${mountPoint}" || fail
  local fstabTag="# cifs mount: ${mountPoint}"

  if ! grep -qFx "${fstabTag}" /etc/fstab; then
    echo "${fstabTag}" | sudo tee -a /etc/fstab >/dev/null || fail
    echo "${serverPath} ${mountPoint} cifs credentials=${credentialsFile},file_mode=644,dir_mode=755,uid=${USER},gid=${USER},forceuid,forcegid,nosetuids,noposix,noserverino,echo_interval=10  0  0" | sudo tee -a /etc/fstab >/dev/null || fail
  fi

  # other mounts might fail, so we ignore exit status here
  sudo mount -a

  findmnt --mountpoint "${mountPoint}" >/dev/null || fail "${mountPoint} is not mounted"
}

mount::ask-for-mount() {
  local mountpoint="$1"

  if ! findmnt --mountpoint "${mountpoint}" >/dev/null; then
    echo "Please attach filesystem to ${mountpoint} and press ENTER"
    read -s || fail
  fi

  findmnt --mountpoint "${mountpoint}" >/dev/null || fail "Unable to find filesystem at ${mountpoint}"
}

path::convert-msys-to-windows() {
  echo "$1" | sed "s/^\\/\\([[:alpha:]]\\)\\//\\1:\\//" | sed "s/\\//\\\\/g"
  test "${PIPESTATUS[*]}" = "0 0 0" || fail
}  
