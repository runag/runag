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

systemd::write_user_unit() {
  local name="$1"

  local user_units_dir="${HOME}/.config/systemd/user"

  dir::ensure_exists --mode 0700 "${HOME}/.config" || softfail || return $?
  dir::ensure_exists --mode 0700 "${HOME}/.config/systemd" || softfail || return $?
  dir::ensure_exists --mode 0700 "${user_units_dir}" || softfail || return $?

  # TODO: --consume?
  file::write --mode 0600 "${user_units_dir}/${name}" || softfail || return $?
}

systemd::write_system_unit() {
  local name="$1"

  # TODO: --consume?
  file::write --sudo --mode 0644 "/etc/systemd/system/${name}" || softfail || return $?
}

systemd::export_shell_function_as_command() {
  # https://www.freedesktop.org/software/systemd/man/latest/systemd.syntax.html#Quoting
  local command; command="$(declare -f "$1" | tail -n +3 | head -n -1 | sed -E "s/^\s*//"; test "${PIPESTATUS[*]}" = "0 0 0 0")" || softfail || return $?
  echo "/usr/bin/bash -c '${command//\'/\\\'}'"
}

systemd::block() {
  local block_name="$1"
  shift
  local block_content; printf -v block_content "\n${block_name}=%s" "$@" || softfail || return $?
  echo "${block_content:1}"
}

systemd::service_tasks() {
  local with_timer
  local action_args=()

  local envelope_command=()

  while [ "$#" -gt 0 ]; do
    case "$1" in
      -e|--envelope)
        envelope_command+=("$2")
        shift; shift
        ;;
      -t|--with-timer)
        action_args+=("$1")
        with_timer=true
        shift
        ;;
      -n|--service-name)
        action_args+=("$1" "$2")
        shift; shift
        ;;
      -u|--user|-c|--ssh-call)
        action_args+=("$1")
        shift
        ;;
      *)
        softfail "Unknown argument: $1" || return $?
        ;;
    esac
  done

  # Service actions (task header)

  task::add "${envelope_command[@]}" systemd::service_action "${action_args[@]}" start || softfail || return $?
  task::add "${envelope_command[@]}" systemd::service_action "${action_args[@]}" stop || softfail || return $?
  
  if [ "${with_timer:-}" = true ]; then
    task::add "${envelope_command[@]}" systemd::service_action "${action_args[@]}" enable_timer || softfail || return $?
    task::add "${envelope_command[@]}" systemd::service_action "${action_args[@]}" disable_timer || softfail || return $?
  fi

  task::add "${envelope_command[@]}" systemd::service_action "${action_args[@]}" status || softfail || return $?
  task::add "${envelope_command[@]}" systemd::service_action "${action_args[@]}" journal  || softfail || return $?
  task::add "${envelope_command[@]}" systemd::service_action "${action_args[@]}" journal --follow || softfail || return $?
}

systemd::service_action() {
  local action_args=()

  local user_services=false
  local ssh_call=false

  while [ "$#" -gt 0 ]; do
    case "$1" in
      -n|--service-name)
        action_args+=("$1" "$2")
        shift; shift
        ;;
      -u|--user)
        action_args+=("$1")
        user_services=true
        shift
        ;;
      -t|--with-timer)
        action_args+=("$1")
        shift
        ;;
      -c|--ssh-call)
        ssh_call=true
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

  local action="$1"; shift

  local ssh_call_command=()

  if [ "${ssh_call}" = true ]; then
    ssh_call_command+=(ssh::call)

    if [ "${user_services}" != true ]; then
      ssh_call_command+=(--root)

    elif [ "${action}" = "journal" ]; then
      # remove this block eventually
      local release_codename; release_codename="$("${ssh_call_command[@]}" lsb_release --codename --short)" || softfail || return $?

      if [ "${release_codename}" = "focal" ]; then
        ssh_call_command+=(--root)
      fi
    fi

    if [ "${action}" = "journal" ] && [ "${1:-}" = "--follow" ]; then
      ssh_call_command+=(--direct)
    fi
  fi

  "${ssh_call_command[@]}" "systemd::service_action::${action}" "${action_args[@]}" "$@" || softfail || return $?
}

systemd::service_action::start() {
  local service_name
  local user_services=false

  while [ "$#" -gt 0 ]; do
    case "$1" in
      -n|--service-name)
        service_name="$2"
        shift; shift
        ;;
      -u|--user)
        user_services=true
        shift
        ;;
      -t|--with-timer)
        shift
        ;;
      *)
        softfail "Unknown argument: $1" || return $?
        ;;
    esac
  done

  if [ "${user_services}" = true ]; then
    systemctl --user --no-block start "${service_name}.service" || softfail || return $?
  else
    sudo systemctl --no-block start "${service_name}.service" || softfail || return $?
  fi
}

systemd::service_action::stop() {
  local service_name
  local user_services=false

  while [ "$#" -gt 0 ]; do
    case "$1" in
      -n|--service-name)
        service_name="$2"
        shift; shift
        ;;
      -u|--user)
        user_services=true
        shift
        ;;
      -t|--with-timer)
        shift
        ;;
      *)
        softfail "Unknown argument: $1" || return $?
        ;;
    esac
  done

  if [ "${user_services}" = true ]; then
    systemctl --user stop "${service_name}.service" || softfail || return $?
  else
    sudo systemctl stop "${service_name}.service" || softfail || return $?
  fi
}

systemd::service_action::disable_timer() {
  local service_name
  local user_services=false

  while [ "$#" -gt 0 ]; do
    case "$1" in
      -n|--service-name)
        service_name="$2"
        shift; shift
        ;;
      -u|--user)
        user_services=true
        shift
        ;;
      -t|--with-timer)
        shift
        ;;
      *)
        softfail "Unknown argument: $1" || return $?
        ;;
    esac
  done

  if [ "${user_services}" = true ]; then
    local systemctl_command=(systemctl --user)
  else
    local systemctl_command=(sudo systemctl)
  fi

  "${systemctl_command[@]}" stop "${service_name}.timer" || softfail || return $?
  "${systemctl_command[@]}" disable "${service_name}.timer" || softfail || return $?
}

systemd::service_action::enable_timer() {
  local service_name
  local user_services=false

  while [ "$#" -gt 0 ]; do
    case "$1" in
      -n|--service-name)
        service_name="$2"
        shift; shift
        ;;
      -u|--user)
        user_services=true
        shift
        ;;
      -t|--with-timer)
        shift
        ;;
      *)
        softfail "Unknown argument: $1" || return $?
        ;;
    esac
  done

  if [ "${user_services}" = true ]; then
    local systemctl_command=(systemctl --user)
  else
    local systemctl_command=(sudo systemctl)
  fi

  "${systemctl_command[@]}" reenable "${service_name}.timer" || softfail || return $?
  "${systemctl_command[@]}" start "${service_name}.timer" || softfail || return $?
}

systemd::service_action::status() {
  local service_name
  local user_services=false
  local with_timer=false

  while [ "$#" -gt 0 ]; do
    case "$1" in
      -n|--service-name)
        service_name="$2"
        shift; shift
        ;;
      -u|--user)
        user_services=true
        shift
        ;;
      -t|--with-timer)
        with_timer=true
        shift
        ;;
      *)
        softfail "Unknown argument: $1" || return $?
        ;;
    esac
  done

  if [ "${user_services}" = true ]; then
    local systemctl_command=(systemctl --user)
  else
    local systemctl_command=(sudo systemctl)
  fi

  local exit_statuses=()

  printf "\n"

  if [ "${with_timer}" = true ]; then
    "${systemctl_command[@]}" list-timers "${service_name}.timer" --all || softfail || return $?
    exit_statuses+=($?)
    printf "\n\n\n"

    "${systemctl_command[@]}" status "${service_name}.timer"
    exit_statuses+=($?)
    printf "\n\n\n"
  fi

  "${systemctl_command[@]}" status "${service_name}.service"
  exit_statuses+=($?)
  printf "\n"

  if [[ "${exit_statuses[*]}" =~ [^0[:space:]] ]]; then
    softfail || return $?
  fi
}

systemd::service_action::journal() (
  local service_name
  local user_services=false
  local follow_argument=()

  while [ "$#" -gt 0 ]; do
    case "$1" in
      -n|--service-name)
        service_name="$2"
        shift; shift
        ;;
      -u|--user)
        user_services=true
        shift
        ;;
      --follow)
        follow_argument=(--follow)
        shift
        ;;
      -t|--with-timer)
        shift
        ;;
      *)
        softfail "Unknown argument: $1" || return $?
        ;;
    esac
  done

  # remove eventually
  # shellcheck disable=SC1091
  . /etc/os-release || softfail || return $?

  if [ "${user_services}" = true ] && [ "${VERSION_CODENAME:-}" = "focal" ]; then
    sudo journalctl "_SYSTEMD_USER_UNIT=${service_name}.service" --lines 2048 "${follow_argument[@]}" || softfail || return $?
    return $?
  fi

  if [ "${user_services}" = true ]; then
    local journalctl_command=(journalctl --user)
  else
    local journalctl_command=(sudo journalctl)
  fi

  "${journalctl_command[@]}" --unit "${service_name}.service" --lines 2048 "${follow_argument[@]}" || softfail || return $?
)
