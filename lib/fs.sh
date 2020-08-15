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

fs::sudo-write-file() {
  local dest="$1"
  local mode="${2:-0644}"
  local owner="${3:-root}"
  local group="${4:-$owner}"

  local dirName; dirName="$(dirname "${dest}")" || fail "Unable to get dirName of '${dest}' ($?)"

  sudo mkdir -p "${dirName}" || fail "Unable to mkdir -p '${dirName}' ($?)"

  cat | sudo tee "$dest" >/dev/null
  test "${PIPESTATUS[*]}" = "0 0" || fail "Unable to cat or write to '$dest'"

  sudo chmod "$mode" "$dest" || fail "Unable to chmod '${dest}' ($?)"
  sudo chown "$owner:$group" "$dest" || fail "Unable to chown '${dest}' ($?)"
}

fs::write-file() {
  local dest="$1"
  local mode="${2:-0644}"

  local dirName; dirName="$(dirname "${dest}")" || fail "Unable to get dirName of '${dest}' ($?)"

  mkdir -p "${dirName}" || fail "Unable to mkdir -p '${dirName}' ($?)"

  cat | tee "$dest" >/dev/null
  test "${PIPESTATUS[*]}" = "0 0" || fail "Unable to cat or write to '$dest'"

  chmod "$mode" "$dest" || fail "Unable to chmod '${dest}' ($?)"
}

fs::remove-dir-if-empty() {
  if [ -d "$1" ]; then
    # if directory is not empty then rm exit status will be non-zero
    rm --dir "$1" || true
  fi
}

fs::mount-cifs() {
  local serverPath="$1"
  local mountName="$2"
  local bwItem="$3"

  local mountPoint="${HOME}/${mountName}"
  local credentialsFile="${HOME}/.${mountName}.cifs-credentials"
  local fstabTag="# ${mountName}"

  mkdir -p "${mountPoint}" || fail

  if ! grep --quiet --fixed-strings --line-regexp "${fstabTag}" /etc/fstab; then
    echo "${fstabTag}" | sudo tee --append /etc/fstab || fail
    echo "${serverPath} ${mountPoint} cifs credentials=${credentialsFile},file_mode=0640,dir_mode=0750,uid=${USER},gid=${USER} 0 0" | sudo tee --append /etc/fstab || fail
  fi

  if [ ! -f "${credentialsFile}" ]; then
    bitwarden::unlock || fail
    local cifsUsername; cifsUsername="$(bw get username "${bwItem}")" || fail
    local cifsPassword; cifsPassword="$(bw get password "${bwItem}")" || fail
    builtin printf "username=${cifsUsername}\npassword=${cifsPassword}\n" | (umask 077 && tee "${credentialsFile}" >/dev/null) || fail
  fi

  sudo mount -a || fail

  findmnt -M "${mountPoint}" >/dev/null || fail "${mountPoint} is not mounted"
}
