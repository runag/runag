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

vmware::linux::is-inside-vm() {
  # another method:
  # if sudo dmidecode -t system | grep --quiet "Product\\ Name\\:\\ VMware\\ Virtual\\ Platform"; then
  hostnamectl status | grep --quiet "Virtualization\\:.*vmware"
}

vmware::linux::add-hgfs-automount() {
  # https://askubuntu.com/a/1051620
  # TODO: Do I really need x-systemd.device-timeout here? think it works well even without it.
  if ! grep --quiet --fixed-strings "fuse.vmhgfs-fuse" /etc/fstab; then
    echo ".host:/  /mnt/hgfs  fuse.vmhgfs-fuse  defaults,allow_other,uid=1000,nofail,x-systemd.device-timeout=1s  0  0" | sudo tee -a /etc/fstab || fail "Unable to write to /etc/fstab ($?)"
  fi
}

vmware::linux::symlink-hgfs-mounts() {
  if findmnt -M /mnt/hgfs >/dev/null; then
    local dirPath dirName
    # I use find here because for..in did not work with hgfs
    find /mnt/hgfs -maxdepth 1 -mindepth 1 -type d | while IFS="" read -r dirPath; do
      dirName="$(basename "$dirPath")" || fail
      if [ ! -e "${HOME}/${dirName}" ]; then
        ln --symbolic "${dirPath}" "${HOME}/${dirName}" || fail "unable to create symlink to ${dirPath}"
      fi
    done
  fi
}

vmware::linux::get-host-ip-address() {
  ip route show | grep 'default via' | awk '{print $3}' | sed -e 's/[[:digit:]]\+$/1/'
  test "${PIPESTATUS[*]}" = "0 0 0 0" || fail
}
