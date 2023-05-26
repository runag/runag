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

linux::set_timezone() {
  local timezone="$1"
  sudo timedatectl set-timezone "${timezone}" || softfail || return $?
}

linux::set_hostname() {
  local hostname="$1"
  sudo hostnamectl set-hostname "${hostname}" || softfail || return $?
  file::append_line_unless_present --sudo /etc/hosts "127.0.1.1	${hostname}" || softfail || return $?
}

linux::dangerously_set_hostname() {
  local hostname="$1"
  local hosts_file=/etc/hosts
  local previous_name
  local previous_name_escaped
  
  previous_name="$(hostnamectl --static status)" || softfail || return $?
  previous_name_escaped="$(echo "${previous_name}" | sed 's/\./\\./g')" || softfail || return $?

  sudo hostnamectl set-hostname "${hostname}" || softfail || return $?

  if [ -f "${hosts_file}" ]; then
    grep -vxE "[[:blank:]]*127.0.1.1[[:blank:]]+${previous_name_escaped}[[:blank:]]*" "${hosts_file}" | sudo tee "${hosts_file}.runag-new" >/dev/null
    test "${PIPESTATUS[*]}" = "0 0" || softfail || return $?
  fi

  file::append_line_unless_present --sudo "${hosts_file}.runag-new" "127.0.1.1	${hostname}" || softfail || return $?

  sudo cp "${hosts_file}" "${hosts_file}.before-runag-changes" || softfail || return $?
  sudo mv "${hosts_file}.runag-new" "${hosts_file}" || softfail || return $?
}

linux::set_locale() {
  local locale="$1"

  sudo locale-gen "${locale}" || softfail || return $?
  sudo update-locale "LANG=${locale}" "LANGUAGE=${locale}" "LC_CTYPE=${locale}" "LC_ALL=${locale}" || softfail || return $?

  export LANG="${locale}"
  export LANGUAGE="${locale}"
  export LC_CTYPE="${locale}"
  export LC_ALL="${locale}"
}

linux::configure_inotify() {
  local max_user_watches="1048576"
  local max_user_instances="2048"

  while [[ "$#" -gt 0 ]]; do
    case $1 in
    -w|--max-user-watches)
      max_user_watches="$2"
      shift; shift
      ;;
    -i|--max-user-instances)
      max_user_instances="$2"
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

  file::write --sudo --mode 0644 /etc/sysctl.d/runag-inotify.conf <<EOF || softfail || return $?
fs.inotify.max_user_watches=${max_user_watches}
fs.inotify.max_user_instances=${max_user_instances}
EOF

  sudo sysctl --system || softfail || return $?
}

linux::display_if_restart_required() {
  if command -v checkrestart >/dev/null; then
    sudo checkrestart || softfail || return $?
  fi

  if [ -x /usr/lib/update-notifier/update-motd-reboot-required ]; then
    /usr/lib/update-notifier/update-motd-reboot-required >&2 || softfail || return $?
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
    sudo adduser --system --group --shell /bin/bash "${user_name}" || softfail || return $?
  fi
}

linux::assign_user_to_group() {
  local user_name="$1"
  local group_name="$2"

  usermod --append --groups "${group_name}" "${user_name}" || softfail || return $?
}

linux::get_default_route() {
  ip route show | grep 'default via' | awk '{print $3}'
  test "${PIPESTATUS[*]}" = "0 0 0" || softfail || return $?
}

linux::get_distributor_id_lowercase() {
  lsb_release --id --short | tr '[:upper:]' '[:lower:]'
  test "${PIPESTATUS[*]}" = "0 0" || softfail || return $?
}

linux::with_secure_temp_dir() {
  local secure_temp_dir
  
  secure_temp_dir="$(mktemp -d)" || softfail || return $?

  # data in tmpfs can be swapped to disk, data in ramfs can't be swapped so we are using ramfs here
  sudo mount -t ramfs -o mode=700 ramfs "${secure_temp_dir}" || softfail || return $?
  sudo chown "${USER}.${USER}" "${secure_temp_dir}" || softfail || return $?

  (
    export TMPDIR="${secure_temp_dir}"
    "$@"
  )

  local result=$?

  sudo umount "${secure_temp_dir}" || softfail || return $?
  rmdir "${secure_temp_dir}" || softfail || return $?

  if [ "${result}" != 0 ]; then
    softfail "Error performing ${1:-"(argument is empty)"} (${result})" || return $?
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

linux::install_runag_essential_dependencies::apt() {
  apt::install \
    apt-transport-https \
    curl \
    git \
    gpg \
    jq \
    pass \
      || softfail || return $?
}
