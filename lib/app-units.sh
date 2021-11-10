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
    unitsList+=("${APP_NAME}-${item}") || fail
  done

  SYSTEMD_COLORS=1 "$@" "${unitsList[@]}" || softfail || return $?
}

app-units::run-for-services-only() {
  local item unitsList=()

  for item in "${appUnits[@]}"; do
    if [[ "${item}" =~ [.]service$ ]]; then
      unitsList+=("${APP_NAME}-${item}") || fail
    fi
  done

  SYSTEMD_COLORS=1 "$@" "${unitsList[@]}" || softfail || return $?
}

app-units::run-with-units() {
  local item unitsList=()

  for item in "${appUnits[@]}"; do
    unitsList+=(--unit "${APP_NAME}-${item}") || fail
  done

  SYSTEMD_COLORS=1 "$@" "${unitsList[@]}" || softfail || return $?
}

app-units::disable() {
  app-units::run systemctl "$@" --quiet disable || softfail || return $?
}

app-units::stop() {
  app-units::run systemctl "$@" stop || softfail || return $?
}

app-units::disable-and-stop() {
  app-units::disable "$@" || softfail || return $?
  app-units::stop "$@" || softfail || return $?
}

app-units::restart() {
  app-units::run systemctl "$@" restart || softfail || return $?
}

app-units::restart-services() {
  app-units::run-for-services-only systemctl "$@" restart || softfail || return $?
}

app-units::statuses() {
  app-units::run systemctl "$@" status || softfail || return $?
}

app-units::journal() {
  app-units::run-with-units journalctl "$@" || softfail || return $?
}

app-units::follow-journal() {
  app-units::run-with-units journalctl --lines=1000 --follow "$@" || softfail || return $?
}

app-units::sopka-menu::add-all::remote() {
  sopka-menu::add "$1" "ssh::run $(printf "%q" "$2") app-units::journal --since yesterday --follow || true" || softfail || return $?
  sopka-menu::add "$1" "ssh::run $(printf "%q" "$2") app-units::follow-journal || true" || softfail || return $?
  sopka-menu::add "$1" ssh::task "$2" app-units::disable || softfail || return $?
  sopka-menu::add "$1" ssh::task "$2" app-units::stop || softfail || return $?
  sopka-menu::add "$1" ssh::task "$2" app-units::disable-and-stop || softfail || return $?
  sopka-menu::add "$1" ssh::task "$2" app-units::restart || softfail || return $?
  sopka-menu::add "$1" ssh::task "$2" app-units::restart-services || softfail || return $?
  sopka-menu::add "$1" ssh::task-verbose "$2" app-units::statuses || softfail || return $?
}
