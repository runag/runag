#!/usr/bin/env bash

#  Copyright 2012-2021 Stanislav Senotrusov <stan@senotrusov.com>
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

app-units::run() {
  local item unitsList=()

  for item in "${appUnits[@]}"; do
    unitsList+=("${APP_NAME}-${item}") || softfail || return $?
  done

  if [ "${SOPKA_STDOUT_IS_TERMINAL:-}" = true ]; then
    local systemdColors=1
  else
    local systemdColors=0
  fi

  SYSTEMD_COLORS="${systemdColors}" "$@" "${unitsList[@]}"
}

app-units::run-for-services-only() {
  local item unitsList=()

  for item in "${appUnits[@]}"; do
    if [[ "${item}" =~ [.]service$ ]]; then
      unitsList+=("${APP_NAME}-${item}") || softfail || return $?
    fi
  done

  if [ "${SOPKA_STDOUT_IS_TERMINAL:-}" = true ]; then
    local systemdColors=1
  else
    local systemdColors=0
  fi

  SYSTEMD_COLORS="${systemdColors}" "$@" "${unitsList[@]}"
}

app-units::run-with-units() {
  local item unitsList=()

  for item in "${appUnits[@]}"; do
    unitsList+=(--unit "${APP_NAME}-${item}") || softfail || return $?
  done

  if [ "${SOPKA_STDOUT_IS_TERMINAL:-}" = true ]; then
    local systemdColors=1
  else
    local systemdColors=0
  fi

  SYSTEMD_COLORS="${systemdColors}" "$@" "${unitsList[@]}"
}

app-units::enable() {
  app-units::run systemctl "$@" --quiet enable || softfail-code $? || return $?
}

app-units::enable-now() {
  app-units::run systemctl "$@" --quiet --now enable || softfail-code $? || return $?
}

app-units::disable() {
  app-units::run systemctl "$@" --quiet disable || softfail-code $? || return $?
}

app-units::disable-now() {
  app-units::run systemctl "$@" --quiet --now disable || softfail-code $? || return $?
}

app-units::start() {
  app-units::run systemctl "$@" --quiet start || softfail-code $? || return $?
}

app-units::stop() {
  app-units::run systemctl "$@" stop || softfail-code $? || return $?
}

app-units::restart() {
  app-units::run systemctl "$@" restart || softfail-code $? || return $?
}

app-units::restart-services() {
  app-units::run-for-services-only systemctl "$@" restart || softfail-code $? || return $?
}

app-units::statuses() {
  app-units::run systemctl "$@" status
  local exitStatus=$?

  if [ "${exitStatus}" != 0 ] && [ "${exitStatus}" != 3 ]; then
    softfail
    return "${exitStatus}"
  fi
}

app-units::journal() {
  app-units::run-with-units journalctl "$@" || softfail-code $? || return $?
}

app-units::follow-journal() {
  app-units::run-with-units journalctl --lines=1000 --follow "$@" || softfail-code $? || return $?
}

app-units::sopka-menu::add-all::remote() {
  sopka-menu::add "$1" ssh::task "$2" app-units::enable || softfail || return $?
  sopka-menu::add "$1" ssh::task "$2" app-units::enable-now || softfail || return $?
  sopka-menu::add "$1" ssh::task "$2" app-units::disable || softfail || return $?
  sopka-menu::add "$1" ssh::task "$2" app-units::disable-now || softfail || return $?
  sopka-menu::add "$1" ssh::task "$2" app-units::start || softfail || return $?
  sopka-menu::add "$1" ssh::task "$2" app-units::stop || softfail || return $?
  sopka-menu::add "$1" ssh::task "$2" app-units::restart || softfail || return $?
  sopka-menu::add "$1" ssh::task "$2" app-units::restart-services || softfail || return $?
  sopka-menu::add-delimiter || softfail || return $?
  sopka-menu::add "$1" ssh::task-verbose "$2" app-units::statuses || softfail || return $?
  sopka-menu::add-raw "$(printf "%q" "$1") ssh::run $(printf "%q" "$2") app-units::journal --since yesterday --follow || true" || softfail || return $?
  sopka-menu::add-raw "$(printf "%q" "$1") ssh::run $(printf "%q" "$2") app-units::follow-journal || true" || softfail || return $?
}
