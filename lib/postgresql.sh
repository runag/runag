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

postgresql::su(){
  local userName
  if [[ "${OSTYPE}" =~ ^darwin ]]; then
    if [ -n "${SUDO_USER:-}" ]; then
      userName="${SUDO_USER}"
    else
      userName="${USER}"
    fi
  else
    userName=postgres
  fi
  echo "sudo -i -u ${userName} psql --username ${userName} --set ON_ERROR_STOP=on"
}

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

postgresql::create-superuser-for-local-account() {
  local userName="${USER}"
  local userExists

  local psqlSu; psqlSu="$(postgresql::su)" || fail

  userExists="$(${psqlSu} --dbname postgres -tA -c "SELECT 1 FROM pg_roles WHERE rolname='${userName}'")" || fail

  if [ "${userExists}" = '1' ]; then
    return 0
  fi

  ${psqlSu} --dbname postgres -c "CREATE ROLE ${userName} WITH SUPERUSER CREATEDB CREATEROLE LOGIN" || fail
}
