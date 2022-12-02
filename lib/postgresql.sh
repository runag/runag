#!/usr/bin/env bash

#  Copyright 2012-2022 Runag project contributors
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

postgresql::install_dictionaries() {
  local source_dir="$1"

  if [ ! -d "${source_dir}" ]; then
    softfail "source_dir does not exists: ${source_dir}"
    return $?
  fi

  if [[ "${OSTYPE}" =~ ^darwin ]]; then
    local dest; for dest in /usr/local/Cellar/postgresql/*; do
      if [ -d "${dest}" ]; then
        local file; for file in "${source_dir}"/*; do
          if [ -f "${file}" ]; then
            cp "${file}" "${dest}/share/postgresql/tsearch_data" || softfail "File copy failed: from '${file}' to '${dest}/share/postgresql/tsearch_data'" || return $?
          fi
        done
      fi
    done
  else
    local dest; for dest in /usr/share/postgresql/*; do
      if [ -d "${dest}" ]; then
        local file; for file in "${source_dir}"/*; do
          if [ -f "${file}" ]; then
            sudo install -o root -g root -m 0644 -C "${file}" -D "${dest}/tsearch_data" || softfail "File install failed: from '${file}' to '${dest}/tsearch_data'" || return $?
          fi
        done
      fi
    done
  fi
}

psql_su() {
  postgresql::psql_su "$@" || softfail || return $?
}

postgresql::psql_su() {
  if [[ "${OSTYPE}" =~ ^darwin ]]; then
    if [ -n "${SUDO_USER:-}" ]; then
      local user_name="${SUDO_USER}"
    else
      local user_name="${USER}"
    fi
  else
    local user_name=postgres
  fi
  
  sudo -i -u "${user_name}" psql --username "${user_name}" --set ON_ERROR_STOP=on "$@" || softfail || return $?
}

postgresql::psql_su_run() {
  postgresql::psql_su --no-align --echo-errors --quiet --tuples-only --command "$@" || softfail || return $?
}

postgresql::psql() {
  psql --set ON_ERROR_STOP=on "$@" || softfail || return $?
}

postgresql::psql_run() {
  postgresql::psql --no-align --echo-errors --quiet --tuples-only --command "$@" || softfail || return $?
}

# TODO: Library users probably will not have any untrusted input here, but perhaps I should account for possible SQL injections

postgresql::create_role_if_not_exists() {
  local user_name="$1"
  if ! postgresql::is_role_exists "${user_name}"; then
    postgresql::psql_su_run "CREATE ROLE ${user_name} ${*:2}" postgres || softfail || return $?
  fi
}

postgresql::is_role_exists() {
  local role_name="${1:-"${PGUSER}"}"
  local role_exists; role_exists="$(postgresql::psql_su_run "SELECT 1 FROM pg_roles WHERE rolname='${role_name}'" postgres)" || fail "Unable to query postgresql" 2 # no softfail here!
  test "${role_exists}" = 1
}

postgresql::is_database_exists() {
  local database_name="${1:-"${PGDATABASE}"}"
  local database_exists; database_exists="$(postgresql::psql_run "SELECT 1 FROM pg_database WHERE datname='${database_name}'" postgres)" || fail "Unable to query postgresql" 2 # no softfail here!
  test "${database_exists}" = 1
}
