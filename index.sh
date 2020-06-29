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

if [ -z "${SOPKA_SRC_DIR:-}" ]; then
  SOPKA_SRC_DIR="$(dirname "${BASH_SOURCE[0]}")" || fail "Unable to determine SOPKA_SRC_DIR ($?)"
  SOPKA_SRC_DIR="$(cd "${SOPKA_SRC_DIR}" >/dev/null 2>&1 && pwd)" || fail "Unable to determine full path for SOPKA_SRC_DIR ($?)"

  export SOPKA_SRC_DIR
fi

. "${SOPKA_SRC_DIR}/lib/benchmark.sh" || fail
. "${SOPKA_SRC_DIR}/lib/bitwarden.sh" || fail
. "${SOPKA_SRC_DIR}/lib/config.sh" || fail
. "${SOPKA_SRC_DIR}/lib/fs.sh" || fail
. "${SOPKA_SRC_DIR}/lib/git.sh" || fail
. "${SOPKA_SRC_DIR}/lib/github.sh" || fail
. "${SOPKA_SRC_DIR}/lib/macos.sh" || fail
. "${SOPKA_SRC_DIR}/lib/menu.sh" || fail
. "${SOPKA_SRC_DIR}/lib/nodejs.sh" || fail
. "${SOPKA_SRC_DIR}/lib/ruby.sh" || fail
. "${SOPKA_SRC_DIR}/lib/shellrcd-files.sh" || fail
. "${SOPKA_SRC_DIR}/lib/shellrcd.sh" || fail
. "${SOPKA_SRC_DIR}/lib/ssh.sh" || fail
. "${SOPKA_SRC_DIR}/lib/tools.sh" || fail
. "${SOPKA_SRC_DIR}/lib/ubuntu-packages.sh" || fail
. "${SOPKA_SRC_DIR}/lib/ubuntu.sh" || fail
