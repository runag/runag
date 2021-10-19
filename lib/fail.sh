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
  exit $?
}

# foo || fail-code <error code>
fail-code() {
  softfail::internal "" "$1"
  exit $?
}

# foo || fail-unless-good ["error message" [<error code>]]
fail-unless-good() {
  softfail-unless-good::internal "$@" || exit $?
}

# foo || fail-unless-good-code <error code>
fail-unless-good-code() {
  softfail-unless-good::internal "" "$1" || exit $?
}


# foo || softfail ["error message" [<error code>]] || return $?
softfail() {
  softfail::internal "$@"
}

# foo || softfail-code <error code> || return $?
softfail-code() {
  softfail::internal "" "$1"
}

# foo || softfail-unless-good ["error message" [<error code>]] || return $?
softfail-unless-good() {
  softfail-unless-good::internal "$@"
}

# foo || softfail-unless-good-code <error code> || return $?
softfail-unless-good-code() {
  softfail-unless-good::internal "" "$1"
}

softfail::internal() {
  local message="${1:-"Abnormal termination"}"
  local exitStatus="${2:-undefined}"

  # make sure we fail if there are some unexpected stuff in exitStatus
  if ! [[ "${exitStatus}" =~ ^[0-9]+$ ]]; then
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
  local exitStatus="${2:-undefined}"

  # make sure we fail if there are some unexpected stuff in exitStatus
  if ! [[ "${exitStatus}" =~ ^[0-9]+$ ]]; then
    exitStatus=1
  fi

  if [ "${exitStatus}" != 0 ]; then
    # making stack trace inside softfail::internal, we dont want to display fail() or softfail() internals in trace
    # so here we start from i=3 (instead of normal i=1) to skip first two lines of stack trace
    log::error-trace "${message}" 3 || echo "Sopka: Unable to log error: ${message}" >&2
  fi

  return "${exitStatus}"
}

# sopka test::fail-foo; echo exit status: $?

# test::fail-foo() {
#   test::fail-bar
# }

# test::fail-bar() {
#   # fail
#   # fail-code 12
#   # fail "foo" 12
#   # fail-unless-good
#   # fail-unless-good "foo"
#   # fail-unless-good "foo" 12
#   # fail-unless-good "foo" 0
#   # fail-unless-good-code 12
#   # fail-unless-good-code 0

#   # softfail || return $?
#   # softfail-code 12 || return $?
#   # softfail "foo" 12 || return $?
#   # softfail-unless-good || return $?
#   # softfail-unless-good "foo" || return $?
#   # softfail-unless-good "foo" 12 || return $?
#   # softfail-unless-good "foo" 0 || return $?
#   # softfail-unless-good-code 12 || return $?
#   # softfail-unless-good-code 0 || return $?

#   echo end of function!!!
# }
