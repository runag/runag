#!/usr/bin/env bash

#  Copyright 2012-2025 Runag project contributors
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

  local previous_name_escaped
  
  # shellcheck disable=SC2001
  previous_name_escaped="$(<<<"${previous_name}" sed 's/\./\\./g')" || softfail || return $?

  file::write --append-line-unless-present --root --mode 0644 "${hosts_file}" "127.0.1.1	${new_name}" || softfail || return $?

  sudo hostnamectl set-hostname "${new_name}" || softfail || return $?

  local temp_file; temp_file="$(mktemp)" || softfail || return $?

  grep -vxE \
    "[[:blank:]]*127.0.1.1[[:blank:]]+${previous_name_escaped}[[:blank:]]*" "${hosts_file}" >"${temp_file}" || softfail || return $?

  file::write --sudo --mode 0644 --consume "${temp_file}" "${hosts_file}" || softfail || return $?
}

linux::update_remote_locale() (
  local locale_list=()

  if [ $# != 0 ]; then
    locale_list=("$@")

    # The server may not have the locales that are present on the local machine
    # If you pass locale variables to it, a slight error may occur
    unset -v LANG LANGUAGE "${!LC_@}" || softfail || return $?

  elif [ -n "${REMOTE_LOCALE:-}" ]; then
    IFS=" " read -r -a locale_list <<<"${REMOTE_LOCALE}" || softfail || return $?
  fi

  if [ "${#locale_list[@]}" = 0 ]; then
    softfail "Locale list is empty"
    return $?
  fi

  # we disable control master to get a clean locale state and not to affect later sessions
  export REMOTE_CONTROL_MASTER=no

  ssh::call linux::reset_locales --ignore-first-run-fright "${locale_list[@]}" || softfail || return $?
)

# linux::reset_locales
#
# Resets and updates system locale settings on a Linux system.
#
# This function performs the following steps:
#   * Uncomments the specified locales in /etc/locale.gen
#   * Regenerates locales with `locale-gen`, unless `--may-skip-locale-gen` is specified and all required locales are already available
#   * Updates /etc/locale.conf with the provided locale environment variables
#   * Unsets any existing locale-related variables in the current shell
#   * Detects a known Bash locale issue and, unless skipped, halts with guidance to retry in a new shell
#   * Exports the new locale variables into the current Bash environment
#
# Usage:
#   linux::reset_locales [options] VAR=VALUE [...]
#
# Options:
#   -i, --ignore-first-run-fright   Skip the workaround check for the known Bash locale issue (useful in automation)
#   -m, --may-skip-locale-gen       Skip locale generation if the required locales already exist in the system
#
# Example:
#   linux::reset_locales LANG=en_US.UTF-8 LC_TIME=de_DE.UTF-8

linux::reset_locales() {
  local ignore_first_run_fright=false
  local may_skip_locale_gen=false

  # Parse options
  while [ "$#" -gt 0 ]; do
    case "$1" in
      -i|--ignore-first-run-fright)
        ignore_first_run_fright=true
        shift
        ;;
      -m|--may-skip-locale-gen)
        may_skip_locale_gen=true
        shift
        ;;
      -*)
        printf 'Unknown argument: %s\n' "$1" >&2
        return 1
        ;;
      *)
        break
        ;;
    esac
  done

  # Loop through remaining arguments (expected to be VAR=locale format)
  local item
  for item in "$@"; do
    # Extract the locale name from the VAR=locale string
    if [[ "$item" =~ ^[[:alpha:]_]+=(.*)$ ]]; then
      local locale_name="${BASH_REMATCH[1]}"

      # Check if locale generation can be skipped (only if requested)
      if [ "$may_skip_locale_gen" = true ]; then
        if ! { { locale -a | grep -qFx "$locale_name"; } || { locale -a | grep -qFx "${locale_name/%.UTF-8/.utf8}"; }; }; then
          may_skip_locale_gen=false # Locale not found - force generation
        fi
      fi

      # Uncomment the corresponding line in /etc/locale.gen to enable the locale
      sudo sed --in-place -E "s/^#\s*(${locale_name//./[.]}(\s|\$))/\1/g" /etc/locale.gen || {
        echo "Failed to update /etc/locale.gen" >&2
        return 1
      }
    fi
  done

  # Regenerate the locales unless it has been confirmed that it can be skipped
  if [ "$may_skip_locale_gen" != true ]; then
    sudo locale-gen --keep-existing || {
      echo "locale-gen failed" >&2
      return 1
    }
  fi

  # Prepare /etc/locale.conf from given variables
  local temp_file
  temp_file="$(mktemp)" || {
    echo "Failed to create temporary file" >&2
    return 1
  }

  {
    local line
    for line in "$@"; do
      printf '%q\n' "$line" || {
        echo "Failed to format locale line" >&2
        return 1
      }
    done
  } >"$temp_file" || {
    echo "Failed to write to temporary file" >&2
    return 1
  }

  sudo install \
    --compare \
    --mode=0644 \
    --owner=root \
    --group=root \
    --no-target-directory \
    "$temp_file" /etc/locale.conf || {
      echo "Failed to update /etc/locale.conf" >&2
      return 1
  }

  rm "$temp_file" || {
    echo "Failed to remove temporary file" >&2
    return 1
  }

  # Clear existing locale variables in the current environment
  unset -v LANG LANGUAGE "${!LC_@}" || {
    echo "Failed to unset locale variables" >&2
    return 1
  }

  # Workaround for a Bash locale quirk.
  #
  # Immediately after a fresh OS install, the first run of this script may trigger a warning like:
  #
  #   <file>: line <line>: warning: setlocale: LC_<type>: cannot change locale (<locale name>): No such file or directory
  #
  # In this situation, Bash itself will not apply the new locale, even though the environment variables are set.
  # However, any child process started from that Bash session *will* respect the new locale settings.
  #
  # The warning only appears once - subsequent runs of the same command in the same or a new shell will succeed quietly.
  #
  # I call `/usr/bin/true` here as a no-op to help trigger and detect the issue.
  #
  # I expect this quirk will be resolved long before Bash gets dead-code elimination - but if not,
  # hello to whoever's maintaining this in the year 2265. Hope you're doing well.
  #
  # Tip: You can test for this condition with: `printf '%(%c)T\n'`
  #
  # It may be worth reporting if it's not already known.

  if [ "$ignore_first_run_fright" != true ]; then
    local error_file
    error_file="$(mktemp)" || {
      echo "Failed to create error log" >&2
      return 1
    }

    # `declare -g` requires Bash 4.2 or newer (released in 2011)
    ( declare -gx "$@" && /usr/bin/true ) 2>"$error_file" || {
      echo "Failed to declare global locale variables" >&2
      return 1
    }

    if [ -s "$error_file" ]; then
      cat "$error_file" >&2 || {
        echo "Failed to display error log" >&2
        return 1
      }

      rm "$error_file" || {
        echo "Failed to remove temporary file" >&2
        return 1
      }

      echo "Unable to apply locale changes in the current shell. Please try running this command again in a new shell." >&2
      return 1
    else
      rm "$error_file" || {
        echo "Failed to remove temporary file" >&2
        return 1
      }
    fi
  fi

  # Final export of the provided locale variables
  # `declare -g` requires Bash 4.2 or newer (released in 2011)
  #   -g global variable scope
  #   -x export
  declare -gx "$@" || {
    echo "Failed to export locale variables" >&2
    return 1
  }
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
  # shellcheck disable=SC1091
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
  # shellcheck disable=SC1091
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
