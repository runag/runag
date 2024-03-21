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

app_unit::run() {
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

app_unit::run_if_exists() {
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

app_unit::run_for_services_only() {
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

app_unit::run_with_units() {
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

app_unit::enable() {
  app_unit::run systemctl "$@" --quiet enable || softfail --exit-status $? || return $?
}

app_unit::enable_now() {
  app_unit::run systemctl "$@" --quiet --now enable || softfail --exit-status $? || return $?
}

app_unit::disable() {
  app_unit::run systemctl "$@" --quiet disable || softfail --exit-status $? || return $?
}

app_unit::disable_if_exists() {
  app_unit::run_if_exists systemctl "$@" --quiet disable || softfail --exit-status $? || return $?
}
  
app_unit::disable_now() {
  app_unit::run systemctl "$@" --quiet --now disable || softfail --exit-status $? || return $?
}

app_unit::disable_now_if_exists() {
  app_unit::run_if_exists systemctl "$@" --quiet --now disable || softfail --exit-status $? || return $?
}

app_unit::start() {
  app_unit::run systemctl "$@" --quiet start || softfail --exit-status $? || return $?
}

app_unit::stop() {
  app_unit::run systemctl "$@" stop || softfail --exit-status $? || return $?
}

app_unit::stop_if_exists() {
  app_unit::run_if_exists systemctl "$@" stop || softfail --exit-status $? || return $?
}

app_unit::restart() {
  app_unit::run systemctl "$@" restart || softfail --exit-status $? || return $?
}

app_unit::restart_services() {
  app_unit::run_for_services_only systemctl "$@" restart || softfail --exit-status $? || return $?
}

app_unit::statuses() {
  app_unit::run systemctl "$@" status
  local exit_status=$?

  if [ "${exit_status}" != 0 ] && [ "${exit_status}" != 3 ]; then
    softfail
    return "${exit_status}"
  fi
}

app_unit::journal() {
  app_unit::run_with_units journalctl "$@" || softfail --exit-status $? || return $?
}

app_unit::follow_journal() {
  app_unit::run_with_units journalctl --lines=1000 --follow "$@" || softfail --exit-status $? || return $?
}

app_unit::menu() {
  menu::add "$1" ssh::call "$2" app_unit::enable || softfail || return $?
  menu::add "$1" ssh::call "$2" app_unit::enable_now || softfail || return $?
  menu::add "$1" ssh::call "$2" app_unit::disable || softfail || return $?
  menu::add "$1" ssh::call "$2" app_unit::disable_now || softfail || return $?
  menu::add "$1" ssh::call "$2" app_unit::start || softfail || return $?
  menu::add "$1" ssh::call "$2" app_unit::stop || softfail || return $?
  menu::add "$1" ssh::call "$2" app_unit::restart || softfail || return $?
  menu::add "$1" ssh::call "$2" app_unit::restart_services || softfail || return $?
  menu::add "$1" ssh::call "$2" app_unit::statuses || softfail || return $?
  menu::add --raw "$(printf "%q" "$1") ssh::run $(printf "%q" "$2") app_unit::journal --since yesterday --follow || true" || softfail || return $?
  menu::add --raw "$(printf "%q" "$1") ssh::run $(printf "%q" "$2") app_unit::follow_journal || true" || softfail || return $?
}
