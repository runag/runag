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

# foo || fail ["error message" [<error code>]]
fail() {
  softfail::internal "$@"
  exit
}

# foo || fail-with-code <error code>
fail-with-code() {
  softfail::internal "" "$1"
  exit
}

# foo || fail-unless-good ["error message" [<error code>]]
fail-unless-good() {
  softfail-unless-good::internal "$@"
  local exitStatus=$?
  if [ "${exitStatus}" != 0 ]; then
    exit "${exitStatus}"
  fi
}

# foo || fail-unless-good-code <error code>
fail-unless-good-code() {
  softfail-unless-good::internal "" "$1"
  local exitStatus=$?
  if [ "${exitStatus}" != 0 ]; then
    exit "${exitStatus}"
  fi
}


# foo || softfail ["error message" [<error code>]] || return
softfail() {
  softfail::internal "$@"
}

# foo || softfail-with-code <error code> || return
softfail-with-code() {
  softfail::internal "" "$1"
}

# foo || softfail-unless-good ["error message" [<error code>]] || return
softfail-unless-good() {
  softfail-unless-good::internal "$@"
}

# foo || softfail-unless-good-code <error code> || return
softfail-unless-good-code() {
  softfail-unless-good::internal "" "$1"
}

softfail::internal() {
  local message="${1:-"Abnormal termination"}"
  local exitStatus="${2:-0}"

  # make sure we fail if there are some unexpected stuff in exitStatus
  if [ -z "${exitStatus##*[!0-9]*}" ]; then
    exitStatus=1
  fi

  # making stack trace inside softfail::internal, we dont want to display fail() or softfail() internals in trace
  # so here we start from i=3 (instead of normal i=1) to skip first two lines of stack trace
  log::error-trace "${message}" 3 || echo "Sopka: Unable to log error: ${message}" >&2

  if [ "${exitStatus}" != 0 ]; then
    return "${exitStatus}"
  fi

  return 1
}

softfail-unless-good::internal() {
  local message="${1:-"Abnormal termination"}"
  local exitStatus="${2:-0}"

  # make sure we fail if there are some unexpected stuff in exitStatus
  if [ -z "${exitStatus##*[!0-9]*}" ]; then
    exitStatus=1
  fi

  if [ "${exitStatus}" != 0 ]; then
    # making stack trace inside softfail::internal, we dont want to display fail() or softfail() internals in trace
    # so here we start from i=3 (instead of normal i=1) to skip first two lines of stack trace
    log::error-trace "${message}" 3 || echo "Sopka: Unable to log error: ${message}" >&2
  fi

  return "${exitStatus}"
}
