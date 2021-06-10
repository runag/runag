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

nvidia::is-card-present() {
  lspci | grep --quiet "VGA.*NVIDIA Corporation"
}

nvidia::fix-screen-tearing() {
  # based on https://www.reddit.com/r/linuxquestions/comments/8fb9oj/how_to_fix_screen_tearing_ubuntu_1804_nvidia_390/
  local modprobeFile="/etc/modprobe.d/zz-nvidia-modeset.conf"
  if [ ! -f "${modprobeFile}" ]; then
    echo "options nvidia_drm modeset=1" | sudo tee "${modprobeFile}"
    test "${PIPESTATUS[*]}" = "0 0" || fail "Unable to write to ${modprobeFile}"
    sudo update-initramfs -u || fail
    echo "Please reboot to activate screen tearing fix" >&2
  fi
}

nvidia::fix-gpu-background-image-glitch() {
  file::sudo-write "/usr/lib/systemd/system-sleep/nvidia--fix-gpu-background-image-glitch.sh" 0755 <<'SHELL' || fail
#!/bin/bash
case $1/$2 in
  pre/*)
    ;;
  post/*)
    if [ -f /var/cache/background-fix-state ]; then
      rm /var/cache/background-fix-state
      su - stan bash -c "DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1000/bus gsettings set org.gnome.desktop.background picture-uri 'file:///usr/share/backgrounds/warty-final-ubuntu.png'"
    else
      touch /var/cache/background-fix-state
      su - stan bash -c "DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1000/bus gsettings set org.gnome.desktop.background picture-uri 'file:///usr/share/backgrounds/Disco_Dingo_Alt_Default_by_Abubakar_NK.png'"
    fi
    ;;
esac
SHELL
}
