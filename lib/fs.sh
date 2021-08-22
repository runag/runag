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

# TODO: chown/chmod first and then write

file::sudo-write() {
  local dest="$1"
  local mode="${2:-}"
  local ownerAndGroup="${3:-}"

  local dirName; dirName="$(dirname "${dest}")" || fail "Unable to get dirName of '${dest}' ($?)"

  sudo mkdir -p "${dirName}" || fail "Unable to mkdir -p '${dirName}' ($?)"

  sudo touch "${dest}" || fail "Unable to touch '${dest}' ($?)"

  if [ -n "${mode}" ]; then
    sudo chmod "${mode}" "${dest}" || fail "Unable to chmod '${dest}' ($?)"
  fi

  if [ -n "${ownerAndGroup}" ]; then
    sudo chown "${ownerAndGroup}" "${dest}" || fail "Unable to chown '${dest}' ($?)"
  fi

  cat | sudo tee "${dest}" >/dev/null
  test "${PIPESTATUS[*]}" = "0 0" || fail "Unable to cat or write to '${dest}'"
}

file::write() {
  local dest="$1"
  local mode="${2:-}"

  local dirName; dirName="$(dirname "${dest}")" || fail "Unable to get dirName of '${dest}' ($?)"

  mkdir -p "${dirName}" || fail "Unable to mkdir -p '${dirName}' ($?)"

  touch "${dest}" || fail "Unable to touch '${dest}' ($?)"

  if [ -n "${mode}" ]; then
    chmod "${mode}" "${dest}" || fail "Unable to chmod '${dest}' ($?)"
  fi

  cat | tee "${dest}" >/dev/null
  test "${PIPESTATUS[*]}" = "0 0" || fail "Unable to cat or write to '${dest}'"
}

file::append-line-unless-present() {
  local string="$1"
  local file="$2"
  if test ! -f "${file}" || ! grep --quiet --fixed-strings --line-regexp "${string}" "${file}"; then
    echo "${string}" | tee -a "${file}" >/dev/null || fail
  fi
}

file::sudo-append-line-unless-present() {
  local string="$1"
  local file="$2"
  if sudo test ! -f "${file}" || ! sudo grep --quiet --fixed-strings --line-regexp "${string}" "${file}"; then
    echo "${string}" | sudo tee -a "${file}" >/dev/null || fail
  fi
}

mount::cifs() {
  local serverPath="$1"
  local mountPoint="$2"
  local bwItem="$3"
  local credentialsFile="$4"

  if [ "${SOPKA_UPDATE_SECRETS:-}" = "true" ] || [ ! -f "${credentialsFile}" ]; then
    bitwarden::unlock || fail

    local credentialsFileDir; credentialsFileDir="$(dirname "${credentialsFile}")" || fail
    mkdir -p "${credentialsFileDir}" || fail

    # bitwarden-object: "?"
    local cifsUsername; cifsUsername="$(NODENV_VERSION=system bw get username "${bwItem}")" || fail
    local cifsPassword; cifsPassword="$(NODENV_VERSION=system bw get password "${bwItem}")" || fail
    builtin printf "username=${cifsUsername}\npassword=${cifsPassword}\n" | (umask 077 && tee "${credentialsFile}" >/dev/null) || fail
  fi

  mkdir -p "${mountPoint}" || fail
  local fstabTag="# cifs mount: ${mountPoint}"

  if ! grep --quiet --fixed-strings --line-regexp "${fstabTag}" /etc/fstab; then
    builtin printf "${fstabTag}\n${serverPath} ${mountPoint} cifs credentials=${credentialsFile},file_mode=0644,dir_mode=0755,uid=${USER},gid=${USER},forceuid,forcegid,nosetuids,noposix,noserverino,echo_interval=10 0 0" | sudo tee -a /etc/fstab >/dev/null || fail
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
