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

cifs::credentials::exists() {
  local credentialsFile="$1"
  test -f "${credentialsFile}"
}

cifs::credentials::save() {
  local cifsUsername="$1"
  local cifsPassword="$2"
  local credentialsFile="$3"
  local mode="${4:-"600"}"
  
  printf "username=%s\npassword=%s\n" "${cifsUsername}" "${cifsPassword}" | file::write "${credentialsFile}" "${mode}"
  test "${PIPESTATUS[*]}" = "0 0" || fail
}

cifs::mount() {
  local serverPath="$1"
  local mountPoint="$2"
  local credentialsFile="$3"
  local fileMode="${4:-"0600"}" 
  local dirMode="${5:-"0700"}" 

  dir::make-if-not-exists "${mountPoint}" "${dirMode}" || fail

  local fstabTag="# cifs mount: ${mountPoint}"

  if ! grep -qFx "${fstabTag}" /etc/fstab; then
    echo "${fstabTag}" | sudo tee -a /etc/fstab >/dev/null || fail
    echo "${serverPath} ${mountPoint} cifs credentials=${credentialsFile},uid=${USER},forceuid,gid=${USER},forcegid,file_mode=${fileMode},dir_mode=${dirMode},nosetuids,echo_interval=10,noserverino,noposix  0  0" | sudo tee -a /etc/fstab >/dev/null || fail
  fi

  # other mounts might fail, so we ignore exit status here
  sudo mount -a

  findmnt --mountpoint "${mountPoint}" >/dev/null || fail "Filesystem is not mounted: ${mountPoint}"
}
