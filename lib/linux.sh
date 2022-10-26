#!/usr/bin/env bash

#  Copyright 2012-2022 Stanislav Senotrusov <stan@senotrusov.com>
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

linux::set_timezone() {
  local timezone="$1"
  sudo timedatectl set-timezone "${timezone}" || fail "Unable to set timezone ($?)"
}

linux::set_hostname() {
  local hostname="$1"
  sudo hostnamectl set-hostname "${hostname}" || fail
  file::sudo_append_line_unless_present "127.0.1.1	${hostname}" /etc/hosts || fail
}

linux::dangerously_set_hostname() {
  local hostname="$1"
  local hosts_file=/etc/hosts
  local previous_name
  local previous_name_escaped
  
  previous_name="$(hostnamectl --static status)" || fail
  previous_name_escaped="$(echo "${previous_name}" | sed 's/\./\\./g')" || fail

  sudo hostnamectl set-hostname "${hostname}" || fail

  if [ -f "${hosts_file}" ]; then
    grep -vxE "[[:blank:]]*127.0.1.1[[:blank:]]+${previous_name_escaped}[[:blank:]]*" "${hosts_file}" | sudo tee "${hosts_file}.sopka-new" >/dev/null
    test "${PIPESTATUS[*]}" = "0 0" || fail
  fi

  file::sudo_append_line_unless_present "127.0.1.1	${hostname}" "${hosts_file}.sopka-new" || fail

  sudo cp "${hosts_file}" "${hosts_file}.before-sopka-changes" || fail
  sudo mv "${hosts_file}.sopka-new" "${hosts_file}" || fail
}

linux::set_locale() {
  local locale="$1"

  sudo locale-gen "${locale}" || fail "Unable to run locale-gen ($?)"
  sudo update-locale "LANG=${locale}" "LANGUAGE=${locale}" "LC_CTYPE=${locale}" "LC_ALL=${locale}" || fail "Unable to run update-locale ($?)"

  export LANG="${locale}"
  export LANGUAGE="${locale}"
  export LC_CTYPE="${locale}"
  export LC_ALL="${locale}"
}

linux::configure_inotify() {
  local max_user_watches="${1:-1048576}"
  local max_user_instances="${2:-2048}"

  file::sudo_write /etc/sysctl.d/sopka-inotify.conf <<EOF || fail
fs.inotify.max_user_watches=${max_user_watches}
fs.inotify.max_user_instances=${max_user_instances}
EOF

  sudo sysctl --system || fail
}

linux::display_if_restart_required() {
  if command -v checkrestart >/dev/null; then
    sudo checkrestart || fail
  fi

  if [ -x /usr/lib/update-notifier/update-motd-reboot-required ]; then
    /usr/lib/update-notifier/update-motd-reboot-required >&2 || fail
  fi
}

linux::display_if_restart_required::install::apt() {
  apt::install debian-goodies || softfail || return $?
}

linux::display_if_restart_required::is_available() {
  if [[ "${OSTYPE}" =~ ^linux ]]; then
    if command -v checkrestart >/dev/null; then
      return 0
    fi
  fi
  return 1
}

linux::is_bare_metal() {
  # "hostnamectl status" could also be used to detect that we are running insde the vm
  ! grep -q "^flags.*:.*hypervisor" /proc/cpuinfo
}

linux::add_user() {
  local user_name="$1"
  if ! id -u "${user_name}" >/dev/null 2>&1; then
    sudo adduser --system --group --shell /bin/bash "${user_name}" || fail
  fi
}

linux::assign_user_to_group() {
  local user_name="$1"
  local group_name="$2"

  usermod --append --groups "${group_name}" "${user_name}" || fail
}

linux::get_default_route() {
  ip route show | grep 'default via' | awk '{print $3}'
  test "${PIPESTATUS[*]}" = "0 0 0" || fail
}

linux::get_distributor_id_lowercase() {
  lsb_release --id --short | tr '[:upper:]' '[:lower:]'
  test "${PIPESTATUS[*]}" = "0 0" || fail
}

linux::with_secure_temp_dir() {
  local secure_temp_dir
  
  secure_temp_dir="$(mktemp -d)" || fail

  # data in tmpfs can be swapped to disk, data in ramfs can't be swapped so we are using ramfs here
  sudo mount -t ramfs -o mode=700 ramfs "${secure_temp_dir}" || fail
  sudo chown "${USER}.${USER}" "${secure_temp_dir}" || fail

  (
    export TMPDIR="${secure_temp_dir}"
    "$@"
  )

  local result=$?

  sudo umount "${secure_temp_dir}" || fail
  rmdir "${secure_temp_dir}" || fail

  if [ "${result}" != 0 ]; then
    fail "Error performing ${1:-"(argument is empty)"} (${result})"
  fi
}

linux::get_user_home() {
  local user_name="$1"
  getent passwd "${user_name}" | cut -d : -f 6
  test "${PIPESTATUS[*]}" = "0 0" || softfail || return $?
}

# do I need it?
# linux::cd_user_home() {
#   local user_name="$1"
#   local user_home; user_home="$(linux::get_user_home "${user_name}")" || softfail || return $?
#   cd "${user_home}" || softfail || return $?
# }

linux::get_cpu_count() {
  local cpu_count; cpu_count="$(grep -c ^processor /proc/cpuinfo 2>/dev/null)"

  if [[ "${cpu_count}" =~ ^[0-9]+$ ]]; then
    echo "${cpu_count}"
  else
    echo 1
  fi
}

linux::get_default_path_variable() {(
  . /etc/environment && echo "${PATH}" || softfail || return $?
)}

linux::get_ipv4_address() {
  local ip_address; ip_address="$(ip route get 1.1.1.1 2>/dev/null | sed -n 's/^.*src \([[:digit:].]*\).*$/\1/p'; test "${PIPESTATUS[*]}" = "0 0")" || softfail "Unable to obtain host ipv6 address" || return $?
  if [ -z "${ip_address}" ]; then
    softfail "Unable to obtain host ipv6 address" || return $?
  fi
  echo "${ip_address}"
}

linux::get_ipv6_address() {
  local ip_address; ip_address="$(ip route get 2606:4700:4700::1111 2>/dev/null | sed -n 's/^.*src \([[:xdigit:]:]*\).*$/\1/p'; test "${PIPESTATUS[*]}" = "0 0")" || softfail "Unable to obtain host ipv6 address" || return $?
  if [ -z "${ip_address}" ]; then
    softfail "Unable to obtain host ipv6 address" || return $?
  fi
  echo "${ip_address}"
}

# gnome-keyring and libsecret (for git and ssh)
linux::install_gnome_keyring_and_libsecret::apt() {
  apt::install \
    gnome-keyring \
    libsecret-tools \
    libsecret-1-0 \
    libsecret-1-dev \
      || softfail || return $?
}

linux::install_sopka_essential_dependencies::apt() {
  apt::install \
    apt-transport-https \
    curl \
    git \
    gpg \
    jq \
    pass \
      || softfail || return $?
}
