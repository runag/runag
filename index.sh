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


# maybe define fail() function
if ! declare -f fail > /dev/null; then
  fail() {
    local i perhapsDelimiter="" startFrom=$((${#BASH_LINENO[@]}-1))
    for ((i=startFrom; i>=1; i--)); do
      if [ ${i} != ${startFrom} ]; then
        printf "\n" >&2
      fi
      if [ ${i} = 1 ]; then
        perhapsDelimiter=": "
      fi
      echo -n "${BASH_SOURCE[${i}]}:${BASH_LINENO[$((i-1))]}: in \`${FUNCNAME[${i}]}'${perhapsDelimiter}" >&2
    done
    echo "${1:-"Abnormal termination"}" >&2
    exit "${2:-1}"
  }
fi


# determine SOPKA_DIR, if not defined previously
if [ -z "${SOPKA_DIR:-}" ]; then
  SOPKA_DIR="$(dirname "${BASH_SOURCE[0]}")" || fail "Unable to determine SOPKA_DIR ($?)"
  SOPKA_DIR="$(cd "${SOPKA_DIR}" >/dev/null 2>&1 && pwd)" || fail "Unable to determine full path for SOPKA_DIR ($?)"

  export SOPKA_DIR
fi


# determine SOPKA_WIN_DIR, if not defined previously
if [[ "${OSTYPE}" =~ ^msys ]]; then
  if [ -z "${SOPKA_WIN_DIR:-}" ]; then
    SOPKA_WIN_DIR="$(echo "${SOPKA_DIR}" | sed "s/^\\/\\([[:alpha:]]\\)\\//\\1:\\//" | sed "s/\\//\\\\/g"; test "${PIPESTATUS[*]}" = "0 0 0" )" || fail
    export SOPKA_WIN_DIR
  fi
fi


# load all libraries
. "${SOPKA_DIR}/lib/apt.sh" || fail
. "${SOPKA_DIR}/lib/benchmark.sh" || fail
. "${SOPKA_DIR}/lib/bitwarden.sh" || fail
. "${SOPKA_DIR}/lib/borg.sh" || fail
. "${SOPKA_DIR}/lib/config.sh" || fail
. "${SOPKA_DIR}/lib/firefox.sh" || fail
. "${SOPKA_DIR}/lib/fs.sh" || fail
. "${SOPKA_DIR}/lib/git.sh" || fail
. "${SOPKA_DIR}/lib/github.sh" || fail
. "${SOPKA_DIR}/lib/imagemagick.sh" || fail
. "${SOPKA_DIR}/lib/keys.sh" || fail
. "${SOPKA_DIR}/lib/linux.sh" || fail
. "${SOPKA_DIR}/lib/macos.sh" || fail
. "${SOPKA_DIR}/lib/menu.sh" || fail
. "${SOPKA_DIR}/lib/nodejs.sh" || fail
. "${SOPKA_DIR}/lib/postgresql.sh" || fail
. "${SOPKA_DIR}/lib/rails.sh" || fail
. "${SOPKA_DIR}/lib/rclone.sh" || fail
. "${SOPKA_DIR}/lib/restic.sh" || fail
. "${SOPKA_DIR}/lib/rsync.sh" || fail
. "${SOPKA_DIR}/lib/ruby.sh" || fail
. "${SOPKA_DIR}/lib/shell.sh" || fail
. "${SOPKA_DIR}/lib/ssh.sh" || fail
. "${SOPKA_DIR}/lib/sublime.sh" || fail
. "${SOPKA_DIR}/lib/syncthing.sh" || fail
. "${SOPKA_DIR}/lib/systemd.sh" || fail
. "${SOPKA_DIR}/lib/tailscale.sh" || fail
. "${SOPKA_DIR}/lib/tools.sh" || fail
. "${SOPKA_DIR}/lib/vmware.sh" || fail
. "${SOPKA_DIR}/lib/vscode.sh" || fail
