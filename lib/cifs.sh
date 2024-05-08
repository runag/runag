#!/usr/bin/env bash

#  Copyright 2012-2022 Rùnag project contributors
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
  local credentials_file="$1"
  test -f "${credentials_file}"
}

cifs::credentials() {
  local credentials_file="$1"
  local cifs_username="$2"
  local cifs_password="$3"

  printf "username=%s\npassword=%s\n" "${cifs_username}" "${cifs_password}" | file::write --mode 0600 "${credentials_file}"
  test "${PIPESTATUS[*]}" = "0 0" || softfail || return $?
}

cifs::mount() {
  local file_mode="0600"
  local dir_mode="0700"

  while [ "$#" -gt 0 ]; do
    case $1 in
      -f|--file-mode)
        file_mode="$2"
        shift; shift
        ;;
      -d|--dir-mode)
        dir_mode="$2"
        shift; shift
        ;;
      -*)
        softfail "Unknown argument: $1" || return $?
        ;;
      *)
        break
        ;;
    esac
  done

  local server_path="$1"
  local mount_point="$2"
  local credentials_file="$3"

  dir::should_exists --mode "${dir_mode}" "${mount_point}" || softfail || return $?

  # TODO: file::read_with_updated_block /etc/fstab SOMETHING | fstab::verify_and_write

  local fstab_tag="# cifs mount: ${mount_point}"

  if ! grep -qFx "${fstab_tag}" /etc/fstab; then
    echo "${fstab_tag}" | sudo tee -a /etc/fstab >/dev/null || softfail || return $?
    echo "${server_path} ${mount_point} cifs credentials=${credentials_file},uid=${USER},forceuid,gid=${USER},forcegid,file_mode=${file_mode},dir_mode=${dir_mode},nosetuids,echo_interval=10,noserverino,noposix  0  0" | sudo tee -a /etc/fstab >/dev/null || softfail || return $?
  fi

  # other mounts might fail, so we ignore exit status here
  sudo mount -a

  findmnt --mountpoint "${mount_point}" >/dev/null || softfail "Filesystem is not mounted: ${mount_point}" || return $?
}
