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
            local file_basename; file_basename="$(basename "${file}")" || softfail || return $?
            file::write --mode 0644 --source "${file}" "${dest}/share/postgresql/tsearch_data/${file_basename}" || softfail || return $?
          fi
        done
      fi
    done
  else
    local dest; for dest in /usr/share/postgresql/*; do
      if [ -d "${dest}" ]; then
        local file; for file in "${source_dir}"/*; do
          if [ -f "${file}" ]; then
            local file_basename; file_basename="$(basename "${file}")" || softfail || return $?
            file::write --sudo --mode 0644 --source "${file}" "${dest}/tsearch_data/${file_basename}" || softfail || return $?
          fi
        done
      fi
    done
  fi
}

postgresql::psql() {
  local psql_command=(psql --set ON_ERROR_STOP=on)
  local arguments_list=()

  while [ "$#" -gt 0 ]; do
    case $1 in
      --sudo)
        local user_name

        if [[ "${OSTYPE}" =~ ^darwin ]]; then
          if [ -n "${SUDO_USER:-}" ]; then
            user_name="${SUDO_USER}"
          else
            user_name="${USER}"
          fi
        else
          user_name=postgres
        fi

        psql_command=(sudo -i -u "${user_name}" psql --username "${user_name}" --set ON_ERROR_STOP=on)

        shift
        ;;
      --query)
        arguments_list=(--no-align --echo-errors --quiet --tuples-only --command "$2")
        shift; shift
        ;;
      *)
        break
        ;;
    esac
  done

  "${psql_command[@]}" "${arguments_list[@]}" "$@"
}

# TODO: Library users probably will not have any untrusted input here, but perhaps I should account for possible SQL injections

postgresql::create_role_if_not_exists() {
  local with_string

  while [ "$#" -gt 0 ]; do
    case $1 in
      --with)
        with_string="WITH $2"
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

  local role_name="${1:-"${PGUSER:-"${USER}"}"}"
  
  if ! postgresql::is_role_exists "${role_name}"; then
    postgresql::psql --sudo --query "CREATE ROLE ${role_name} ${with_string:-}" --dbname postgres || softfail || return $?
  fi
}

postgresql::is_role_exists() {
  local role_name="${1:-"${PGUSER:-"${USER}"}"}"

  local role_exists

  role_exists="$(postgresql::psql --sudo --query "SELECT 1 FROM pg_roles WHERE rolname='${role_name}'" --dbname postgres)" || fail --exit-status 2 "Unable to query postgresql" # no softfail here!

  test "${role_exists}" = 1
}

postgresql::is_database_exists() {
  local database_name="${1:-"${PGDATABASE}"}"

  local database_exists
  
  database_exists="$(postgresql::psql --query "SELECT 1 FROM pg_database WHERE datname='${database_name}'" --dbname postgres)" || fail --exit-status 2 "Unable to query postgresql" # no softfail here!

  test "${database_exists}" = 1
}
