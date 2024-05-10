#!/usr/bin/env bash

#  Copyright 2012-2024 Rùnag project contributors
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

vmware::is_inside_vm() {
  if [[ "${OSTYPE}" =~ ^linux ]]; then
    hostnamectl status | grep -q "Virtualization:.*vmware"

    local saved_pipe_status="${PIPESTATUS[*]}"

    if [ "${saved_pipe_status}" = "0 0" ]; then
      return 0
    elif [ "${saved_pipe_status}" = "0 1" ]; then
      return 1
    else
      fail "Error calling hostnamectl status"
    fi

    # another method:
    # if sudo dmidecode -t system | grep -q "Product Name: VMware Virtual Platform"; then
  
  elif [[ "${OSTYPE}" =~ ^msys ]]; then
    powershell -Command "Get-WmiObject Win32_computerSystem" | grep -qF "VMware"

    local saved_pipe_status="${PIPESTATUS[*]}"

    if [ "${saved_pipe_status}" = "0 0" ]; then
      return 0
    elif [ "${saved_pipe_status}" = "0 1" ]; then
      return 1
    else
      fail "Error calling Get-WmiObject"
    fi

  else
    fail "OSTYPE not supported: ${OSTYPE}"
  fi
}

vmware::use_hgfs_mounts() {
  vmware::add_hgfs_automount || softfail || return $?
  vmware::symlink_hgfs_mounts || softfail || return $?
}

vmware::add_hgfs_automount() {
  local mount_point="${1:-"/mnt/hgfs"}"

  # https://askubuntu.com/a/1051620
  # TODO: Do I really need x-systemd.device-timeout here? think it works well even without it.
  # TODO: file::read_with_updated_block /etc/fstab HGFS_AUTOMOUNT | fstab::verify_and_write
  if ! grep -qF "fuse.vmhgfs-fuse" /etc/fstab; then
    echo ".host:/  ${mount_point}  fuse.vmhgfs-fuse  defaults,allow_other,uid=1000,nofail,x-systemd.device-timeout=1s  0  0" | sudo tee -a /etc/fstab >/dev/null || softfail "Unable to write to /etc/fstab ($?)" || return $?
  fi
}

vmware::symlink_hgfs_mounts() {
  local mount_point="/mnt/hgfs"
  local symlinks_directory="${HOME}"

  while [ "$#" -gt 0 ]; do
    case $1 in
      -m|--mount-point)
        mount_point="$2"
        shift; shift
        ;;
      -s|--symlinks-directory)
        symlinks_directory="$2"
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

  if findmnt --mountpoint "${mount_point}" >/dev/null; then
    local dir_path dir_name
    # I use find here because for..in did not work with hgfs
    find "${mount_point}" -maxdepth 1 -mindepth 1 -type d | while IFS="" read -r dir_path; do
      dir_name="$(basename "${dir_path}")" || softfail || return $?
      if [ ! -e "${symlinks_directory}/${dir_name}" ]; then
        ln --symbolic "${dir_path}" "${symlinks_directory}/${dir_name}" || softfail "unable to create symlink to ${dir_path}" || return $?
      fi
    done
  fi
}

vmware::get_host_ip_address() {
  local ip_address; ip_address="$(ip route get 1.1.1.1 | sed -n 's/^.*via \([[:digit:].]*\).*$/\1/p' | sed 's/[[:digit:]]\+$/1/'; test "${PIPESTATUS[*]}" = "0 0 0")" || softfail "Unable to obtain host ip address" || return $?
  if [ -z "${ip_address}" ]; then
    softfail "Unable to obtain host ip address" || return $?
  fi
  echo "${ip_address}"
}

vmware::configure_passwordless_sudo_for_dmidecode_in_get_machine_uuid() {
  <<<"${USER} ALL=NOPASSWD: /usr/sbin/dmidecode" file::write --sudo --mode 0440 /etc/sudoers.d/dmidecode || softfail || return $?
}

vmware::get_machine_uuid() {
  sudo dmidecode -t system | grep "^[[:blank:]]*Serial Number: VMware-" | sed "s/^[[:blank:]]*Serial Number: VMware-//" | sed "s/ //g"
  test "${PIPESTATUS[*]}" = "0 0 0 0" || softfail || return $?
}

vmware::vm_network_loss_workaround() {
  if ip address show ens33 >/dev/null 2>&1; then
    if ! ip address show ens33 | grep -qF "inet "; then
      echo "vmware::vm_network_loss_workaround: about to restart network"
      sudo systemctl restart NetworkManager.service || fail "Unable to restart network"
      sudo dhclient || fail "Error running dhclient"
    fi
  fi
}

vmware::install_vm_network_loss_workaround() {
  file::write --sudo --mode 0755 /usr/local/bin/vmware-vm-network-loss-workaround <<SHELL || softfail || return $?
$(runag::mini_library)
$(declare -f vmware::vm_network_loss_workaround)
vmware::vm_network_loss_workaround || fail "Unable to perform vmware::vm_network_loss_workaround"
SHELL

  file::write --sudo --mode 0644 /etc/systemd/system/vmware-vm-network-loss-workaround.service <<EOF || softfail || return $?
[Unit]
Description=vmware-vm-network-loss-workaround

[Service]
Type=oneshot
ExecStart=/usr/local/bin/vmware-vm-network-loss-workaround
WorkingDirectory=/
EOF

  file::write --sudo --mode 0644 /etc/systemd/system/vmware-vm-network-loss-workaround.timer <<EOF || softfail || return $?
[Unit]
Description=vmware-vm-network-loss-workaround

[Timer]
OnCalendar=minutely
Persistent=true

[Install]
WantedBy=timers.target
EOF

  sudo systemctl --quiet reenable vmware-vm-network-loss-workaround.timer || softfail || return $?
  sudo systemctl start vmware-vm-network-loss-workaround.timer || softfail || return $?
}
