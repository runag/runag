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

ubuntu::is-bare-metal() {
  # "hostnamectl status" could also be used to detect that we are running insde the vm
  if grep --quiet "^flags.*:.*hypervisor" /proc/cpuinfo; then
    return 1
  else
    return 0
  fi
}

ubuntu::set-timezone() {
  local timezone="$1"
  sudo timedatectl set-timezone "$timezone" || fail "Unable to set timezone ($?)"
}

ubuntu::set-hostname() {
  local hostname="$1"
  local hostnameFile=/etc/hostname

  echo "$hostname" | sudo tee "$hostnameFile" || fail "Unable to write to $hostnameFile ($?)"

  sudo hostname --file "$hostnameFile" || fail "Unable to load hostname from $hostnameFile ($?)"
}

ubuntu::set-locale() {
  local locale="$1"

  sudo locale-gen "$locale" || fail "Unable to run locale-gen ($?)"
  sudo update-locale "LANG=$locale" "LANGUAGE=$locale" "LC_CTYPE=$locale" "LC_ALL=$locale" || fail "Unable to run update-locale ($?)"

  export LANG="$locale"
  export LANGUAGE="$locale"
  export LC_CTYPE="$locale"
  export LC_ALL="$locale"
}

ubuntu::set-inotify-max-user-watches() {
  local sysctl="/etc/sysctl.conf"

  if [ ! -r "$sysctl" ]; then
    echo "Unable to find file: $sysctl" >&2
    exit 1
  fi

  if grep --quiet "^fs.inotify.max_user_watches" "$sysctl" && grep --quiet "^fs.inotify.max_user_instances" "$sysctl"; then
    echo "fs.inotify.max_user_watches and fs.inotify.max_user_instances are already set" >&2
  else
    echo "fs.inotify.max_user_watches=1000000" | sudo tee -a "$sysctl" || fail "Unable to write to $sysctl ($?)"

    echo "fs.inotify.max_user_instances=2048" | sudo tee -a "$sysctl" || fail "Unable to write to $sysctl ($?)"

    sudo sysctl -p || fail "Unable to update sysctl config ($?)"
  fi
}

ubuntu::fix-nvidia-gpu-background-image-glitch() {
  sudo install --mode=0755 --owner=root --group=root -D -t /usr/lib/systemd/system-sleep "${SOPKA_SRC_DIR}/lib/ubuntu/background-fix.sh" || fail "Unable to install background-fix.sh ($?)"
}

ubuntu::perhaps-fix-nvidia-screen-tearing() {
  # based on https://www.reddit.com/r/linuxquestions/comments/8fb9oj/how_to_fix_screen_tearing_ubuntu_1804_nvidia_390/
  local modprobeFile="/etc/modprobe.d/zz-nvidia-modeset.conf"
  if lspci | grep --quiet "VGA.*NVIDIA Corporation"; then
    if [ ! -f "${modprobeFile}" ]; then
      echo "options nvidia_drm modeset=1" | sudo tee "${modprobeFile}"
      test "${PIPESTATUS[*]}" = "0 0" || fail "Unable to write to ${modprobeFile}"
      sudo update-initramfs -u || fail
      echo "Please reboot to activate screen tearing fix (ubuntu::perhaps-fix-nvidia-screen-tearing)" >&2
    fi
  fi
}

ubuntu::add-ssh-key-password-to-keyring() {
  # There is an indirection here. I assume that if there is a DBUS_SESSION_BUS_ADDRESS available then
  # the login keyring is also available and already initialized properly
  # I don't know yet how to check for login keyring specifically
  if [ -n "${DBUS_SESSION_BUS_ADDRESS:-}" ]; then
    if ! secret-tool lookup unique "ssh-store:${HOME}/.ssh/id_rsa" >/dev/null; then
      bitwarden::unlock || fail
      bw get password "my current password for ssh private key" \
        | secret-tool store --label="Unlock password for: ${HOME}/.ssh/id_rsa" unique "ssh-store:${HOME}/.ssh/id_rsa"
      test "${PIPESTATUS[*]}" = "0 0" || fail "Unable to obtain and store ssh key password"
    fi
  else
    echo "Unable to store ssh key password into the gnome keyring, DBUS not found" >&2
  fi
}

ubuntu::compile-git-credential-libsecret() (
  if [ ! -f /usr/share/doc/git/contrib/credential/libsecret/git-credential-libsecret ]; then
    cd /usr/share/doc/git/contrib/credential/libsecret || fail
    sudo make || fail "Unable to compile libsecret"
  fi
)

ubuntu::add-git-credentials-to-keyring() {
  # There is an indirection here. I assume that if there is a DBUS_SESSION_BUS_ADDRESS available then
  # the login keyring is also available and already initialized properly
  # I don't know yet how to check for login keyring specifically
  if [ -n "${DBUS_SESSION_BUS_ADDRESS:-}" ]; then
    if ! secret-tool lookup server github.com user "${GITHUB_LOGIN}" protocol https xdg:schema org.gnome.keyring.NetworkPassword >/dev/null; then
      bitwarden::unlock || fail
      bw get password "my github personal access token" \
        | secret-tool store --label="Git: https://github.com/" server github.com user "${GITHUB_LOGIN}" protocol https xdg:schema org.gnome.keyring.NetworkPassword
      test "${PIPESTATUS[*]}" = "0 0" || fail "Unable to obtain and store github personal access token"
    fi
  else
    echo "Unable to store git credentials into the gnome keyring, DBUS not found" >&2
  fi

  git config --global credential.helper /usr/share/doc/git/contrib/credential/libsecret/git-credential-libsecret || fail
}

ubuntu::perhaps-add-hgfs-automount() {
  # https://askubuntu.com/a/1051620
  # TODO: Do I really need x-systemd.device-timeout here? think it works well even without it.
  if hostnamectl status | grep --quiet "Virtualization\\:.*vmware"; then
    if ! grep --quiet --fixed-strings "fuse.vmhgfs-fuse" /etc/fstab; then
      echo ".host:/  /mnt/hgfs  fuse.vmhgfs-fuse  defaults,allow_other,uid=1000,nofail,x-systemd.device-timeout=1s  0  0" | sudo tee -a /etc/fstab || fail "Unable to write to /etc/fstab ($?)"
    fi
  fi
}

ubuntu::symlink-hgfs-mounts() {
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

ubuntu::setup-imwhell() {
  local repetitions="2"
  local outputFile="${HOME}/.imwheelrc"
  tee "${outputFile}" <<SHELL || fail "Unable to write file: ${outputFile} ($?)"
".*"
None,      Up,   Button4, ${repetitions}
None,      Down, Button5, ${repetitions}
Control_L, Up,   Control_L|Button4
Control_L, Down, Control_L|Button5
Shift_L,   Up,   Shift_L|Button4
Shift_L,   Down, Shift_L|Button5
SHELL

  if [ ! -d "${HOME}/.config/autostart" ]; then
    mkdir -p "${HOME}/.config/autostart" || fail
  fi

  local outputFile="${HOME}/.config/autostart/imwheel.desktop"
  tee "${outputFile}" <<SHELL || fail "Unable to write file: ${outputFile} ($?)"
[Desktop Entry]
Type=Application
Exec=/usr/bin/imwheel
Hidden=false
NoDisplay=false
X-GNOME-Autostart-enabled=true
OnlyShowIn=GNOME;XFCE;
Name[en_US]=IMWheel
Name=IMWheel
Comment[en_US]=Custom scroll speed
Comment=Custom scroll speed
SHELL

  /usr/bin/imwheel --kill
}

ubuntu::display-if-restart-required() {
  sudo checkrestart || fail

  if [ -x /usr/lib/update-notifier/update-motd-reboot-required ]; then
    /usr/lib/update-notifier/update-motd-reboot-required >&2 || fail
  fi
}

ubuntu::hide-folder() {
  local hiddenFile="${HOME}/.hidden"

  touch "${hiddenFile}" || fail

  if ! grep --quiet "^$1\$" "${hiddenFile}"; then
    echo "$1" >>"${hiddenFile}" || fail
  fi
}

ubuntu::moz-enable-wayland() {
  local pamFile="${HOME}/.pam_environment"
  touch "${pamFile}" || fail

  if ! grep --quiet "^MOZ_ENABLE_WAYLAND" "${pamFile}"; then
    echo "MOZ_ENABLE_WAYLAND=1" >>"${pamFile}" || fail
  fi
}
