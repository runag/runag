#!/usr/bin/env bash

#  Copyright 2012-2019 Stanislav Senotrusov <stan@senotrusov.com>
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

if ! declare -f fail > /dev/null; then
  fail() {
    echo "${BASH_SOURCE[1]}:${BASH_LINENO[0]}: in \`${FUNCNAME[1]}': Error: ${1:-"Abnormal termination"}" >&2
    exit "${2:-1}"
  }
fi

if [ -z "${SOPKA_LIB_DIR:-}" ]; then
  SOPKA_LIB_DIR="$(dirname "${BASH_SOURCE[0]}")" || fail "Unable to determine SOPKA_LIB_DIR ($?)"
  SOPKA_LIB_DIR="$(cd "${SOPKA_LIB_DIR}" >/dev/null 2>&1 && pwd)" || fail "Unable to determine full path for SOPKA_LIB_DIR ($?)"

  export SOPKA_LIB_DIR
fi

if [[ "$OSTYPE" =~ ^msys ]]; then
  if [ -z "${SOPKA_LIB_WIN_DIR:-}" ]; then
    SOPKA_LIB_WIN_DIR="$(echo "${SOPKA_LIB_DIR}" | sed "s/^\\/\\([[:alpha:]]\\)\\//\\1:\\//" | sed "s/\\//\\\\/g"; test "${PIPESTATUS[*]}" = "0 0 0" )" || fail
    export SOPKA_LIB_WIN_DIR
  fi
fi

. "${SOPKA_LIB_DIR}/lib/benchmark.sh" || fail
. "${SOPKA_LIB_DIR}/lib/bitwarden.sh" || fail
. "${SOPKA_LIB_DIR}/lib/borg.sh" || fail
. "${SOPKA_LIB_DIR}/lib/config.sh" || fail
. "${SOPKA_LIB_DIR}/lib/fs.sh" || fail
. "${SOPKA_LIB_DIR}/lib/git.sh" || fail
. "${SOPKA_LIB_DIR}/lib/github.sh" || fail
. "${SOPKA_LIB_DIR}/lib/macos.sh" || fail
. "${SOPKA_LIB_DIR}/lib/menu.sh" || fail
. "${SOPKA_LIB_DIR}/lib/nodejs.sh" || fail
. "${SOPKA_LIB_DIR}/lib/ruby.sh" || fail
. "${SOPKA_LIB_DIR}/lib/shellrcd-files.sh" || fail
. "${SOPKA_LIB_DIR}/lib/shellrcd.sh" || fail
. "${SOPKA_LIB_DIR}/lib/ssh.sh" || fail
. "${SOPKA_LIB_DIR}/lib/sublime.sh" || fail
. "${SOPKA_LIB_DIR}/lib/tools.sh" || fail
. "${SOPKA_LIB_DIR}/lib/ubuntu-desktop.sh" || fail
. "${SOPKA_LIB_DIR}/lib/ubuntu-nvidia.sh" || fail
. "${SOPKA_LIB_DIR}/lib/ubuntu-packages.sh" || fail
. "${SOPKA_LIB_DIR}/lib/ubuntu-vmware.sh" || fail
. "${SOPKA_LIB_DIR}/lib/ubuntu.sh" || fail
. "${SOPKA_LIB_DIR}/lib/vscode.sh" || fail
. "${SOPKA_LIB_DIR}/lib/windows.sh" || fail
