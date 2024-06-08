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

linux::set_timezone() {
  local timezone="$1"
  sudo timedatectl set-timezone "${timezone}" || softfail || return $?
}

linux::set_hostname() {
  local new_name="$1"

  local hosts_file="/etc/hosts"
  
  local previous_name; previous_name="$(hostnamectl --static status)" || softfail || return $?

  if [ "${new_name}" = "${previous_name}" ]; then
    return 0
  fi

  local previous_name_escaped; previous_name_escaped="$(<<<"${previous_name}" sed 's/\./\\./g')" || softfail || return $?

  file::append_line_unless_present --sudo --keep-permissions --mode 0644 "${hosts_file}" "127.0.1.1	${new_name}" || softfail || return $?

  sudo hostnamectl set-hostname "${new_name}" || softfail || return $?

  local temp_file; temp_file="$(mktemp)" || softfail || return $?

  grep -vxE \
    "[[:blank:]]*127.0.1.1[[:blank:]]+${previous_name_escaped}[[:blank:]]*" "${hosts_file}" >"${temp_file}" || softfail || return $?

  file::write --sudo --keep-permissions --mode 0644 --absorb "${temp_file}" "${hosts_file}" || softfail || return $?
}

linux::update_remote_locale() (
  # The server may not have the locales that are present on the local machine
  # If you pass locale variables to it, a slight error may occur
  lunux::unset_all_locales || fail

  # we disable control master to get a clean locale state and not to affect later sessions
  export REMOTE_CONTROL_MASTER=no

  ssh::call linux::reset_locales "$@" || fail
)

lunux::unset_all_locales() {
  # man 5 locale
  # https://wiki.debian.org/Locale
  unset -v \
    LANG \
    LANGUAGE \
    LC_ALL \
    \
    LC_COLLATE \
    LC_CTYPE \
    LC_MESSAGES \
    LC_MONETARY \
    LC_NUMERIC \
    LC_TIME \
    \
    LC_ADDRESS \
    LC_IDENTIFICATION \
    LC_MEASUREMENT \
    LC_NAME \
    LC_PAPER \
    LC_RESPONSE \
    LC_TELEPHONE
}

linux::reset_locales() {
  sudo locale-gen --keep-existing || softfail || return $?
  sudo update-locale --reset "$@" || softfail || return $?

  lunux::unset_all_locales || softfail || return $?

  # -g global variable scope
  # -x export
  declare -gx "$@" || softfail || return $?
}

linux::configure_inotify() {
  local max_user_watches="1048576"
  local max_user_instances="2048"

  while [ "$#" -gt 0 ]; do
    case "$1" in
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

linux::is_user_exists() {
  local user_name="$1"
  id -u "${user_name}" >/dev/null 2>&1
}

linux::get_default_route() {
  ip route show | grep 'default via' | awk '{print $3}'
  test "${PIPESTATUS[*]}" = "0 0 0" || softfail || return $?
}

linux::with_secure_temp_dir() {
  local secure_temp_dir
  
  secure_temp_dir="$(mktemp -d)" || softfail || return $?

  # data in tmpfs can be swapped to disk, data in ramfs can't be swapped so we are using ramfs here
  sudo mount -t ramfs -o mode=700 ramfs "${secure_temp_dir}" || softfail || return $?
  sudo chown "${USER}:${USER}" "${secure_temp_dir}" || softfail || return $?

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

linux::get_home_dir() { 
  local user_name="$1"
  getent passwd "${user_name}" | cut -d : -f 6
  test "${PIPESTATUS[*]}" = "0 0" || softfail || return $?
}

# linux::adduser --quiet --disabled-password --gecos "bar" bar
linux::adduser() {
  local user_name="${*: -1}"

  if ! id -u "${user_name}" >/dev/null 2>&1; then
    sudo adduser "$@" || softfail || return $?
  fi
}

linux::get_cpu_count() {
  local cpu_count; cpu_count="$(grep -c ^processor /proc/cpuinfo 2>/dev/null)"

  if [[ "${cpu_count}" =~ ^[0-9]+$ ]]; then
    echo "${cpu_count}"
  else
    echo 1
  fi
}

linux::get_default_path_env() {(
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

linux::set_battery_charge_control_threshold() {
  local battery_number=0
  local if_present=false
  local start_threshold=90
  local end_threshold=100

  while [ "$#" -gt 0 ]; do
    case "$1" in
      -b|--battery)
        battery_number="$2"
        shift; shift
        ;;
      -p|--if-present)
        if_present=true
        shift
        ;;
      -s|--start)
        start_threshold="$2"
        shift; shift
        ;;
      -e|--end)
        end_threshold="$2"
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

  local battery_path="/sys/class/power_supply/BAT${battery_number}"

  if [ ! -d "${battery_path}" ]; then
    if [ "${if_present}" = true ]; then
      return 0
    else
      softfail "Battery not found: ${battery_path}" || return $?
    fi
  fi

  <<<"100" sudo tee "${battery_path}/charge_control_end_threshold" >/dev/null || softfail || return $?
  <<<"${start_threshold}" sudo tee "${battery_path}/charge_control_start_threshold" >/dev/null || softfail || return $?
  <<<"${end_threshold}" sudo tee "${battery_path}/charge_control_end_threshold" >/dev/null || softfail || return $?
}
