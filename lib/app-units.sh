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

# shellcheck disable=2154

app_units::run() {
  local item units_list=()

  for item in "${app_units[@]}"; do
    units_list+=("${APP_NAME}-${item}") || softfail || return $?
  done

  if [ "${RUNAG_STDOUT_IS_TERMINAL:-}" = true ]; then
    local systemd_colors=1
  else
    local systemd_colors=0
  fi

  SYSTEMD_COLORS="${systemd_colors}" "$@" "${units_list[@]}"
}

app_units::run_if_exists() {
  local item units_list=()

  for item in "${app_units[@]}"; do
    units_list+=("${APP_NAME}-${item}") || softfail || return $?
  done

  if [ "${RUNAG_STDOUT_IS_TERMINAL:-}" = true ]; then
    local systemd_colors=1
  else
    local systemd_colors=0
  fi

  for item in "${units_list[@]}"; do
    if systemctl cat "${item}" >/dev/null 2>&1; then
      SYSTEMD_COLORS="${systemd_colors}" "$@" "${units_list[@]}" || softfail || return $?
    fi
  done
}

app_units::run_for_services_only() {
  local item units_list=()

  for item in "${app_units[@]}"; do
    if [[ "${item}" =~ [.]service$ ]]; then
      units_list+=("${APP_NAME}-${item}") || softfail || return $?
    fi
  done

  if [ "${RUNAG_STDOUT_IS_TERMINAL:-}" = true ]; then
    local systemd_colors=1
  else
    local systemd_colors=0
  fi

  SYSTEMD_COLORS="${systemd_colors}" "$@" "${units_list[@]}"
}

app_units::run_with_units() {
  local item units_list=()

  for item in "${app_units[@]}"; do
    units_list+=(--unit "${APP_NAME}-${item}") || softfail || return $?
  done

  if [ "${RUNAG_STDOUT_IS_TERMINAL:-}" = true ]; then
    local systemd_colors=1
  else
    local systemd_colors=0
  fi

  SYSTEMD_COLORS="${systemd_colors}" "$@" "${units_list[@]}"
}

app_units::enable() {
  app_units::run systemctl "$@" --quiet enable || softfail --code $? || return $?
}

app_units::enable_now() {
  app_units::run systemctl "$@" --quiet --now enable || softfail --code $? || return $?
}

app_units::disable() {
  app_units::run systemctl "$@" --quiet disable || softfail --code $? || return $?
}

app_units::disable_if_exists() {
  app_units::run_if_exists systemctl "$@" --quiet disable || softfail --code $? || return $?
}
  
app_units::disable_now() {
  app_units::run systemctl "$@" --quiet --now disable || softfail --code $? || return $?
}

app_units::disable_now_if_exists() {
  app_units::run_if_exists systemctl "$@" --quiet --now disable || softfail --code $? || return $?
}

app_units::start() {
  app_units::run systemctl "$@" --quiet start || softfail --code $? || return $?
}

app_units::stop() {
  app_units::run systemctl "$@" stop || softfail --code $? || return $?
}

app_units::stop_if_exists() {
  app_units::run_if_exists systemctl "$@" stop || softfail --code $? || return $?
}

app_units::restart() {
  app_units::run systemctl "$@" restart || softfail --code $? || return $?
}

app_units::restart_services() {
  app_units::run_for_services_only systemctl "$@" restart || softfail --code $? || return $?
}

app_units::statuses() {
  app_units::run systemctl "$@" status
  local exit_status=$?

  if [ "${exit_status}" != 0 ] && [ "${exit_status}" != 3 ]; then
    softfail
    return "${exit_status}"
  fi
}

app_units::journal() {
  app_units::run_with_units journalctl "$@" || softfail --code $? || return $?
}

app_units::follow_journal() {
  app_units::run_with_units journalctl --lines=1000 --follow "$@" || softfail --code $? || return $?
}

app_units::runagfile_menu() {
  runagfile_menu::add "$1" ssh::task "$2" app_units::enable || softfail || return $?
  runagfile_menu::add "$1" ssh::task "$2" app_units::enable_now || softfail || return $?
  runagfile_menu::add "$1" ssh::task "$2" app_units::disable || softfail || return $?
  runagfile_menu::add "$1" ssh::task "$2" app_units::disable_now || softfail || return $?
  runagfile_menu::add "$1" ssh::task "$2" app_units::start || softfail || return $?
  runagfile_menu::add "$1" ssh::task "$2" app_units::stop || softfail || return $?
  runagfile_menu::add "$1" ssh::task "$2" app_units::restart || softfail || return $?
  runagfile_menu::add "$1" ssh::task "$2" app_units::restart_services || softfail || return $?
  runagfile_menu::add "$1" ssh::task_verbose "$2" app_units::statuses || softfail || return $?
  runagfile_menu::add --raw "$(printf "%q" "$1") ssh::run $(printf "%q" "$2") app_units::journal --since yesterday --follow || true" || softfail || return $?
  runagfile_menu::add --raw "$(printf "%q" "$1") ssh::run $(printf "%q" "$2") app_units::follow_journal || true" || softfail || return $?
}
