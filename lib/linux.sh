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
  local locale_list=()

  if [ $# != 0 ]; then
    locale_list=("$@")

    # The server may not have the locales that are present on the local machine
    # If you pass locale variables to it, a slight error may occur
    shell::unset_locales || fail

  elif [ -n "${REMOTE_LOCALE:-}" ]; then
    IFS=" " read -r -a locale_list <<<"${REMOTE_LOCALE}" || softfail || return $?
  fi

  if [ "${#locale_list[@]}" = 0 ]; then
    softfail "Locale list is empty"
    return $?
  fi

  # we disable control master to get a clean locale state and not to affect later sessions
  export REMOTE_CONTROL_MASTER=no

  ssh::call linux::reset_locales --carry-on "${locale_list[@]}" || softfail || return $?
)

linux::reset_locales() {
  local carry_on=false

  while [ "$#" -gt 0 ]; do
    case "$1" in
      -c|--carry-on)
        carry_on=true
        shift
        ;;
      -*)
        softfail "Unknown argument: $1" || return $?
        ;;
      *)
        break
        ;;
    esac
  done

  local item; for item in "$@"; do
    if [[ "${item}" =~ ^[[:alpha:]_]+=(.*)$ ]]; then
      local locale_match; locale_match="$(<<<"${BASH_REMATCH[1]}" sed -E 's/[.]/[.]/g')" || softfail || return $?
      sudo sed --in-place -E 's/^#\s*('"${locale_match}"'(\s|$))/\1/g' /etc/locale.gen || softfail || return $?
    fi
  done

  sudo locale-gen --keep-existing || softfail || return $?

  # sudo update-locale --reset "$@" || softfail || return $?
  # the following should do the same

  local temp_file; temp_file="$(mktemp)" || softfail || return $?
  {
    local locale_line; for locale_line in "$@"; do
      printf "%q\n" "${locale_line}" || softfail || return $?
    done
  } >"${temp_file}" || softfail || return $?

  file::write --sudo --absorb "${temp_file}" --mode 0644 /etc/locale.conf || softfail || return $?

  shell::unset_locales || softfail || return $?

  # Workaround for strange bash behaviour
  #
  # Right after fresh OS install you may get the following warning on the first script run:
  #
  # <file>: line <line>: warning: setlocale: LC_<type>: cannot change locale (<locale name>): No such file or directory
  #
  # In that case bash will not change it's own locale, as requested, but any child process started from that bash
  # will use new locale as specified in environment.
  #
  # The same command will produce no warnings on every consecutive run
  #
  # I expect this peculiarity to be fixed before bash will get dead-code elimination, but if it's not going to happen
  # then /usr/bin/true here is just for you guys from 2265, I hope that you are doing great there.
  #
  # printf '%(%c)T\n' could be used to test that case
  #
  if [ "${carry_on}" = false ]; then
    local temp_file; temp_file="$(mktemp)" || softfail || return $?

    ( declare -gx "$@" && /usr/bin/true ) 2>"${temp_file}" || softfail || return $?

    if [ -s "${temp_file}" ]; then
      cat "${temp_file}" >&2 || softfail || return $?
      rm "${temp_file}" || softfail || return $?
      softfail "Unable to change locale, please try to run the same command once again in a new bash process"
      return $?
    else
      rm "${temp_file}" || softfail || return $?
    fi
  fi

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
linux::install_gnome_keyring_and_libsecret() (
  . /etc/os-release || softfail || return $?

  if [ "${ID:-}" = debian ] || [ "${ID_LIKE:-}" = debian ]; then
    apt::install \
      gnome-keyring \
      libsecret-tools \
      libsecret-1-0 \
      libsecret-1-dev \
        || softfail || return $?

  elif [ "${ID:-}" = arch ]; then
    sudo pacman --sync --needed --noconfirm \
      gnome-keyring \
      libsecret \
        || softfail || return $?

  else
    softfail "Your operating system is not supported" || return $?
  fi
)

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

linux::user_media_path() {
  if [ -d /run/media ]; then
    echo "/run/media/${USER}"

  elif [ -d /media ]; then
    echo "/media/${USER}"

  else
    softfail "Unable to determine user mounts path" || return $?
  fi
}
