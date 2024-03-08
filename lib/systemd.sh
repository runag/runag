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
  local ssh_call_prefix=()
  local ssh_call_direct_prefix=()
  local systemctl_args=()
  local library_function_arguments=()
  local with_timer=false
  local user_services=false
  local ssh_call=false

  while [ "$#" -gt 0 ]; do
    case $1 in
    -n|--name)
      service_name="$2"
      shift; shift
      ;;
    -w|--ssh-call-with)
      ssh_call=true
      ssh_call_prefix+=("$2")
      ssh_call_direct_prefix+=("$2" "--direct")
      shift; shift
      ;;
    -s|--ssh-call)
      ssh_call=true
      ssh_call_prefix+=("ssh::call")
      ssh_call_direct_prefix+=("ssh::call" "--direct")
      shift; shift
      ;;
    -u|--user)
      user_services=true
      systemctl_args+=("--user")
      library_function_arguments+=("--user")
      shift
      ;;
    -t|--with-timer)
      with_timer=true
      library_function_arguments+=("--with-timer")
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

  runagfile_menu::add "${ssh_call_prefix[@]}" systemctl "${systemctl_args[@]}" --no-block start "${service_name}.service" || softfail || return $?
  runagfile_menu::add "${ssh_call_prefix[@]}" systemctl "${systemctl_args[@]}" stop "${service_name}.service" || softfail || return $?

  if [ "${with_timer}" = true ]; then
    runagfile_menu::add "${ssh_call_prefix[@]}" systemd::disable_timer "${library_function_arguments[@]}" "${service_name}" || softfail || return $?
  fi

  runagfile_menu::add "${ssh_call_prefix[@]}" systemd::show_status "${library_function_arguments[@]}" "${service_name}" || softfail || return $?

  # TODO: eventually remove 
  if [ "${user_services}" = true ]; then
    local release_codename; release_codename="$("${ssh_call_prefix[@]}" lsb_release --codename --short)" || softfail || return $?
    if [ "${release_codename}" = focal ]; then
      if [ "${ssh_call}" = true ]; then
        ssh_call_prefix+=("--root") # Watch out!
        ssh_call_direct_prefix+=("--root") # Watch out!
      fi
      runagfile_menu::add "${ssh_call_prefix[@]}"        journalctl "_SYSTEMD_USER_UNIT=${service_name}.service" --since today || softfail || return $?
      runagfile_menu::add "${ssh_call_direct_prefix[@]}" journalctl "_SYSTEMD_USER_UNIT=${service_name}.service" --since today --follow || softfail || return $?
      return # Watch out!
    fi
  fi

  runagfile_menu::add "${ssh_call_prefix[@]}"        journalctl "${systemctl_args[@]}" -u "${service_name}.service" --since today || softfail || return $?
  runagfile_menu::add "${ssh_call_direct_prefix[@]}" journalctl "${systemctl_args[@]}" -u "${service_name}.service" --since today --follow || softfail || return $?
}

systemd::disable_timer() {
  local systemctl_args=()

  while [ "$#" -gt 0 ]; do
    case $1 in
    -u|--user)
      systemctl_args+=("--user")
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

  systemctl "${systemctl_args[@]}" stop "${1}.timer" || softfail || return $?
  systemctl "${systemctl_args[@]}" --quiet disable "${1}.timer" || softfail || return $?
}

systemd::show_status() {
  local systemctl_args=()
  local with_timer=false

  while [ "$#" -gt 0 ]; do
    case $1 in
    -u|--user)
      systemctl_args+=("--user")
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
    systemctl "${systemctl_args[@]}" list-timers "${1}.timer" --all || softfail || return $?
    exit_statuses+=($?)
    printf "\n\n\n"

    systemctl "${systemctl_args[@]}" status "${1}.timer"
    exit_statuses+=($?)
    printf "\n\n\n"
  fi

  systemctl "${systemctl_args[@]}" status "${1}.service"
  exit_statuses+=($?)
  printf "\n"

  if [[ "${exit_statuses[*]}" =~ [^03[:space:]] ]]; then # I'm not sure about number 3 here
    softfail || return $?
  fi
}
