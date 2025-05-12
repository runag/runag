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

# shellcheck disable=SC2030
postgresql::install_dictionaries() (
  local source_dir="$1"

  test -d "${source_dir}" || softfail "The directory does not exist: ${source_dir}" || return $?

  # Load operating system identification data
  # shellcheck disable=SC1091
  . /etc/os-release || softfail || return $?

  if [[ "${OSTYPE}" =~ ^linux ]]; then

    if [ "${ID:-}" = debian ] || [ "${ID_LIKE:-}" = debian ]; then
      local dest_found=false
 
      local dest; for dest in /usr/share/postgresql/*; do
        test -d "${dest}" || continue
        postgresql::install_dictionaries::do || softfail || return $?
        dest_found=true
      done
 
      if [ "${dest_found}" = false ]; then
        softfail "No destination were found for installation"
        return $?
      fi

    elif [ "${ID:-}" = arch ]; then
      local dest="/usr/share/postgresql"
      test -d "${dest}" || softfail "Destination directory not found: ${dest}" || return $?
      postgresql::install_dictionaries::do || softfail || return $?

    else
      softfail "Your operating system is not supported"
      return $?
    fi
  else
    softfail "Your operating system is not supported"
    return $?
  fi
)

# shellcheck disable=SC2031
postgresql::install_dictionaries::do() {
  local file_found=false
 
  local file; for file in "${source_dir}"/*; do
    test -f "${file}" || continue
 
    local file_basename; file_basename="$(basename "${file}")" || softfail || return $?
    file::write --sudo --mode 0644 --copy "${file}" "${dest}/tsearch_data/${file_basename}" || softfail || return $?
 
    file_found=true
  done
 
  if [ "${file_found}" = false ]; then
    softfail "No files were found for installation"
    return $?
  fi
}

postgresql::psql() {
  local psql_command=(psql --set ON_ERROR_STOP=on)
  local arguments_list=()

  while [ "$#" -gt 0 ]; do
    case "$1" in
      --sudo)
        local user_name

        # TODO: Check if that's ok for darwin
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

postgresql::as_postgres_user() {
  local postgres_user

  # TODO: Check if that's ok for darwin
  if [[ "${OSTYPE}" =~ ^darwin ]]; then
    if [ -n "${SUDO_USER:-}" ]; then
      postgres_user="${SUDO_USER}"
    else
      postgres_user="${USER}"
    fi
  else
    postgres_user=postgres
  fi

  sudo -i -u "${postgres_user}" "$@"
}

# TODO: Library users probably will not have any untrusted input here, but perhaps I should account for possible SQL injections

postgresql::create_role_if_not_exists() {
  local with_string

  while [ "$#" -gt 0 ]; do
    case "$1" in
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

  role_exists="$(postgresql::psql --sudo --query "SELECT 1 FROM pg_roles WHERE rolname='${role_name}'" --dbname postgres)" || fail --status 2 "Unable to query postgresql" # no softfail here!

  test "${role_exists}" = 1
}

postgresql::is_database_exists() {
  local database_name="${1:-"${PGDATABASE}"}"

  local database_exists
  
  database_exists="$(postgresql::psql --query "SELECT 1 FROM pg_database WHERE datname='${database_name}'" --dbname postgres)" || fail --status 2 "Unable to query postgresql" # no softfail here!

  test "${database_exists}" = 1
}
