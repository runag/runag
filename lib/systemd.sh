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

systemd::write_user_unit() {
  local name="$1"

  local user_units_dir="${HOME}/.config/systemd/user"

  dir::should_exists --mode 0700 "${HOME}/.config" || softfail || return $?
  dir::should_exists --mode 0700 "${HOME}/.config/systemd" || softfail || return $?
  dir::should_exists --mode 0700 "${user_units_dir}" || softfail || return $?

  # TODO: --absorb?
  file::write --mode 0600 "${user_units_dir}/${name}" || softfail || return $?
}

systemd::write_system_unit() {
  local name="$1"

  # TODO: --absorb?
  file::write --sudo --mode 0644 "/etc/systemd/system/${name}" || softfail || return $?
}

systemd::runagfile_menu() {
  local service_name
  local ssh_call
  local ssh_call_prefix
  local user_services
  local with_timer

  while [ "$#" -gt 0 ]; do
    case $1 in
    -n|--name)
      service_name="$2"
      shift; shift
      ;;
    -w|--ssh-call-with)
      ssh_call=true
      ssh_call_prefix="$2"
      shift; shift
      ;;
    -s|--ssh-call)
      ssh_call=true
      ssh_call_prefix="ssh::call"
      shift
      ;;
    -u|--user)
      user_services=true
      shift
      ;;
    -t|--with-timer)
      with_timer=true
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

  runagfile_menu::add --header "Actions on ${service_name} services" || softfail || return $?

  runagfile_menu::add ${ssh_call:+"${ssh_call_prefix}"} systemctl ${user_services:+"--user"} --no-block start "${service_name}.service" || softfail || return $?
  runagfile_menu::add ${ssh_call:+"${ssh_call_prefix}"} systemctl ${user_services:+"--user"} stop "${service_name}.service" || softfail || return $?

  if [ "${with_timer:-}" = true ]; then
    runagfile_menu::add ${ssh_call:+"${ssh_call_prefix}"} systemd::disable_timer ${user_services:+"--user"} "${service_name}" || softfail || return $?
  fi

  runagfile_menu::add ${ssh_call:+"${ssh_call_prefix}"} systemd::show_status ${user_services:+"--user"} ${with_timer:+"--with-timer"} "${service_name}" || softfail || return $?

  # TODO: eventually remove 
  if [ "${user_services:-}" = true ]; then
    local release_codename; release_codename="$(${ssh_call:+"${ssh_call_prefix}"} lsb_release --codename --short)" || softfail || return $?
    if [ "${release_codename}" = focal ]; then
      runagfile_menu::add ${ssh_call:+"${ssh_call_prefix}"} ${ssh_call:+"--root"} journalctl "_SYSTEMD_USER_UNIT=${service_name}.service" --since today || softfail || return $?
      runagfile_menu::add ${ssh_call:+"${ssh_call_prefix}"} ${ssh_call:+"--root"} ${ssh_call:+"--direct"} journalctl "_SYSTEMD_USER_UNIT=${service_name}.service" --since today --follow || softfail || return $?
      return # Watch out!
    fi
  fi

  runagfile_menu::add ${ssh_call:+"${ssh_call_prefix}"} journalctl ${user_services:+"--user"} -u "${service_name}.service" --since today || softfail || return $?
  runagfile_menu::add ${ssh_call:+"${ssh_call_prefix}"} ${ssh_call:+"--direct"} journalctl ${user_services:+"--user"} -u "${service_name}.service" --since today --follow || softfail || return $?
}

systemd::disable_timer() {
  local user_services

  while [ "$#" -gt 0 ]; do
    case $1 in
    -u|--user)
      user_services=true
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

  systemctl ${user_services:+"--user"} stop "${1}.timer" || softfail || return $?
  systemctl ${user_services:+"--user"} --quiet disable "${1}.timer" || softfail || return $?
}

systemd::enable_timer() {
  local user_services

  while [ "$#" -gt 0 ]; do
    case $1 in
    -u|--user)
      user_services=true
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

  systemd-analyze ${user_services:+"--user"} verify "${1}.service" || fail
  systemctl ${user_services:+"--user"} --quiet reenable "${1}.timer" || fail
  systemctl ${user_services:+"--user"} start "${1}.timer" || fail
}

systemd::show_status() {
  local user_services
  local with_timer=false

  while [ "$#" -gt 0 ]; do
    case $1 in
    -u|--user)
      user_services=true
      shift
      ;;
    -t|--with-timer)
      with_timer=true
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

  local exit_statuses=()

  printf "\n"

  if [ "${with_timer}" = true ]; then
    systemctl ${user_services:+"--user"} list-timers "${1}.timer" --all || softfail || return $?
    exit_statuses+=($?)
    printf "\n\n\n"

    systemctl ${user_services:+"--user"} status "${1}.timer"
    exit_statuses+=($?)
    printf "\n\n\n"
  fi

  systemctl ${user_services:+"--user"} status "${1}.service"
  exit_statuses+=($?)
  printf "\n"

  if [[ "${exit_statuses[*]}" =~ [^03[:space:]] ]]; then # I'm not sure about number 3 here
    softfail || return $?
  fi
}
