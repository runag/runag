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

postgresql::install-dictionaries() {
  local folder="$1"

  if [[ "${OSTYPE}" =~ ^darwin ]]; then
    local dest; for dest in /usr/local/Cellar/postgresql/*; do
      if [ -d "${dest}" ]; then
        local file; for file in "${folder}"/*; do
          if [ -f "${file}" ]; then
            cp "${file}" "${dest}/share/postgresql/tsearch_data" || fail
          fi
        done
      fi
    done
  else
    local dest; for dest in /usr/share/postgresql/*; do
      if [ -d "${dest}" ]; then
        local file; for file in "${folder}"/*; do
          if [ -f "${file}" ]; then
            sudo install --owner=root --group=root --mode=0644 "${file}" -D "${dest}/tsearch_data" || fail
          fi
        done
      fi
    done
  fi
}

psql-su(){
  postgresql::psql-su "$@" || softfail || return $?
}

postgresql::psql-su(){
  if [[ "${OSTYPE}" =~ ^darwin ]]; then
    if [ -n "${SUDO_USER:-}" ]; then
      local userName="${SUDO_USER}"
    else
      local userName="${USER}"
    fi
  else
    local userName=postgres
  fi
  
  sudo -i -u "${userName}" psql --username "${userName}" --set ON_ERROR_STOP=on "$@" || softfail || return $?
}

postgresql::psql-su-run(){
  postgresql::psql-su --no-align --echo-errors --quiet --tuples-only --command "$@" || softfail || return $?
}

postgresql::psql(){
  psql --set ON_ERROR_STOP=on "$@" || softfail || return $?
}

postgresql::psql-run(){
  postgresql::psql --no-align --echo-errors --quiet --tuples-only --command "$@" || softfail || return $?
}

# TODO: Library users probably will not have any untrusted input here, but perhaps I should account for possible SQL injections

postgresql::create-role-if-not-exists() {
  local userName="$1"
  if ! postgresql::is-role-exists "${userName}"; then
    postgresql::psql-su-run "CREATE ROLE ${userName} ${*:2}" postgres || softfail || return $?
  fi
}

postgresql::is-role-exists() {
  local roleName="${1:-"${PGUSER}"}"
  local roleExists; roleExists="$(postgresql::psql-su-run "SELECT 1 FROM pg_roles WHERE rolname='${roleName}'" postgres)" || fail "Unable to query postgresql" 2 # no softfail here!
  test "${roleExists}" = 1
}

postgresql::is-database-exists() {
  local databaseName="${1:-"${PGDATABASE}"}"
  local databaseExists; databaseExists="$(postgresql::psql-run "SELECT 1 FROM pg_database WHERE datname='${databaseName}'" postgres)" || fail "Unable to query postgresql" 2 # no softfail here!
  test "${databaseExists}" = 1
}
