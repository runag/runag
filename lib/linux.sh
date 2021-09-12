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

linux::set-timezone() {
  local timezone="$1"
  sudo timedatectl set-timezone "${timezone}" || fail "Unable to set timezone ($?)"
}

linux::set-hostname() {
  local hostname="$1"
  sudo hostnamectl set-hostname "${hostname}" || fail
  file::sudo-append-line-unless-present "127.0.1.1	${hostname}" /etc/hosts || fail
}

linux::dangerously-set-hostname() {
  local hostname="$1"
  local hostsFile=/etc/hosts
  local previousName
  local previousNameEscaped
  
  previousName="$(hostnamectl --static status)" || fail
  previousNameEscaped="$(echo "${previousName}" | sed 's/\./\\./g')" || fail

  sudo hostnamectl set-hostname "${hostname}" || fail

  if [ -f "${hostsFile}" ]; then
    grep --invert-match --line-regexp --extended-regexp "[[:blank:]]*127.0.1.1[[:blank:]]+${previousNameEscaped}[[:blank:]]*" "${hostsFile}" | sudo tee "${hostsFile}.sopka-new" >/dev/null
    test "${PIPESTATUS[*]}" = "0 0" || fail
  fi

  file::sudo-append-line-unless-present "127.0.1.1	${hostname}" "${hostsFile}.sopka-new" || fail

  sudo cp "${hostsFile}" "${hostsFile}.before-sopka-changes" || fail
  sudo mv "${hostsFile}.sopka-new" "${hostsFile}" || fail
}

linux::set-locale() {
  local locale="$1"

  sudo locale-gen "${locale}" || fail "Unable to run locale-gen ($?)"
  sudo update-locale "LANG=${locale}" "LANGUAGE=${locale}" "LC_CTYPE=${locale}" "LC_ALL=${locale}" || fail "Unable to run update-locale ($?)"

  export LANG="${locale}"
  export LANGUAGE="${locale}"
  export LC_CTYPE="${locale}"
  export LC_ALL="${locale}"
}

linux::configure-inotify() {
  local max_user_watches="${1:-1048576}"
  local max_user_instances="${2:-2048}"

  file::sudo-write /etc/sysctl.d/sopka-inotify.conf <<EOF || fail
fs.inotify.max_user_watches=${max_user_watches}
fs.inotify.max_user_instances=${max_user_instances}
EOF

  sudo sysctl --system || fail
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

linux::get-distributor-id-lowercase() {
  lsb_release --id --short | tr '[:upper:]' '[:lower:]'
  test "${PIPESTATUS[*]}" = "0 0" || fail
}

linux::with-secure-tmpdir() {
  local secureTmpDir
  
  secureTmpDir="$(mktemp -d)" || fail

  # data in tmpfs can be swapped to disk, data in ramfs can't be swapped so we are using ramfs here
  sudo mount -t ramfs -o mode=700 ramfs "${secureTmpDir}" || fail
  sudo chown "${USER}.${USER}" "${secureTmpDir}" || fail

  (
    export TMPDIR="${secureTmpDir}"
    "$@"
  )

  local result=$?

  sudo umount "${secureTmpDir}" || fail
  rmdir "${secureTmpDir}" || fail

  if [ "${result}" != 0 ]; then
    fail "Error performing ${1:-"(argument is empty)"} (${result})"
  fi
}
