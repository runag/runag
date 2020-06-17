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

if [ -n "${VERBOSE:-}" ]; then
  set -o xtrace
fi

set -o nounset

fail() {
  echo "${BASH_SOURCE[1]}:${BASH_LINENO[0]}: in \`${FUNCNAME[1]}': Error: ${1:-"Abnormal termination"}" >&2
  exit "${2:-1}"
}

STAN_DEPLOY_LIB_DIR="$(dirname "${BASH_SOURCE[0]}")" || fail "Unable to determine STAN_DEPLOY_LIB_DIR ($?)"
STAN_DEPLOY_LIB_DIR="$(cd "${STAN_DEPLOY_LIB_DIR}" >/dev/null 2>&1 && pwd)" || fail "Unable to determine full path for STAN_DEPLOY_LIB_DIR ($?)"

export STAN_DEPLOY_LIB_DIR

. "${STAN_DEPLOY_LIB_DIR}/lib/benchmark.sh" || fail
. "${STAN_DEPLOY_LIB_DIR}/lib/bitwarden.sh" || fail
. "${STAN_DEPLOY_LIB_DIR}/lib/config-files.sh" || fail
. "${STAN_DEPLOY_LIB_DIR}/lib/deploy-lib.sh" || fail
. "${STAN_DEPLOY_LIB_DIR}/lib/filesystem.sh" || fail
. "${STAN_DEPLOY_LIB_DIR}/lib/git.sh" || fail
. "${STAN_DEPLOY_LIB_DIR}/lib/github.sh" || fail
. "${STAN_DEPLOY_LIB_DIR}/lib/macos.sh" || fail
. "${STAN_DEPLOY_LIB_DIR}/lib/nodejs.sh" || fail
. "${STAN_DEPLOY_LIB_DIR}/lib/ruby.sh" || fail
. "${STAN_DEPLOY_LIB_DIR}/lib/shellrcd-files.sh" || fail
. "${STAN_DEPLOY_LIB_DIR}/lib/shellrcd.sh" || fail
. "${STAN_DEPLOY_LIB_DIR}/lib/ssh.sh" || fail
. "${STAN_DEPLOY_LIB_DIR}/lib/ubuntu-packages.sh" || fail
. "${STAN_DEPLOY_LIB_DIR}/lib/ubuntu.sh" || fail
