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

linux::set-timezone() {
  local timezone="$1"
  sudo timedatectl set-timezone "$timezone" || fail "Unable to set timezone ($?)"
}

linux::set-hostname() {
  local hostname="$1"
  local hostnameFile=/etc/hostname
  local hostsFile=/etc/hosts
  local hostsString="127.0.1.1 $hostname"

  echo "$hostname" | sudo tee "$hostnameFile" || fail "Unable to write to $hostnameFile ($?)"
  sudo hostname --file "$hostnameFile" || fail "Unable to load hostname from $hostnameFile ($?)"

  if [ ! -f "${hostsFile}" ]; then
    fail "File not found: ${hostsFile}"
  fi

  if ! grep --quiet --fixed-strings --line-regexp "${hostsString}" "${hostsFile}"; then
    echo "${hostsString}" | sudo tee --append "${hostsFile}" || fail
  fi
}

linux::set-locale() {
  local locale="$1"

  sudo locale-gen "$locale" || fail "Unable to run locale-gen ($?)"
  sudo update-locale "LANG=$locale" "LANGUAGE=$locale" "LC_CTYPE=$locale" "LC_ALL=$locale" || fail "Unable to run update-locale ($?)"

  export LANG="$locale"
  export LANGUAGE="$locale"
  export LC_CTYPE="$locale"
  export LC_ALL="$locale"
}

linux::configure-inotify() {
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

linux::display-if-restart-required() {
  if command -v checkrestart >/dev/null; then
    sudo checkrestart || fail
  fi

  if [ -x /usr/lib/update-notifier/update-motd-reboot-required ]; then
    /usr/lib/update-notifier/update-motd-reboot-required >&2 || fail
  fi
}

linux::is-bare-metal() {
  # "hostnamectl status" could also be used to detect that we are running insde the vm
  ! grep --quiet "^flags.*:.*hypervisor" /proc/cpuinfo
}

linux::add-user() {
  local userName="$1"
  if ! id -u "${userName}" >/dev/null 2>&1; then
    sudo adduser --system --group --shell /bin/bash "${userName}" || fail
  fi
}

linux::assign-user-to-group() {
  local userName="$1"
  local groupName="$2"

  usermod --append --groups "${groupName}" "${userName}" || fail
}

linux::get-default-route() {
  ip route show | grep 'default via' | awk '{print $3}'
  test "${PIPESTATUS[*]}" = "0 0 0" || fail
}

linux::enable-nonrestricted-sudo() {
  local userName="${1:-"${USER}"}"

  file::sudo-write "/etc/sudoers.d/${userName}-nonrestricted-sudo" 0440 root <<SHELL || fail
${userName} ALL=(ALL) NOPASSWD: ALL
SHELL
}

linux::disable-nonrestricted-sudo() {
  local userName="${1:-"${USER}"}"

  sudo rm -f "/etc/sudoers.d/${userName}-nonrestricted-sudo" || fail
}
