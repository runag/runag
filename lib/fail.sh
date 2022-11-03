#!/usr/bin/env bash

#  Copyright 2012-2022 Stanislav Senotrusov <stan@senotrusov.com>
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

# foo || fail_code <error code>
fail_code() {
  softfail::internal "" "$1"
  exit $?
}

# foo || fail_unless_good ["error message" [<error code>]]
fail_unless_good() {
  softfail_unless_good::internal "$@" || exit $?
}

# foo || fail_unless_good_code <error code>
fail_unless_good_code() {
  softfail_unless_good::internal "" "$1" || exit $?
}


# foo || softfail ["error message" [<error code>]] || return $?
softfail() {
  softfail::internal "$@"
}

# foo || softfail_code <error code> || return $?
softfail_code() {
  softfail::internal "" "$1"
}

# foo || softfail_unless_good ["error message" [<error code>]] || return $?
softfail_unless_good() {
  softfail_unless_good::internal "$@"
}

# foo || softfail_unless_good_code <error code> || return $?
softfail_unless_good_code() {
  softfail_unless_good::internal "" "$1"
}

softfail::internal() {
  local message="${1:-"Abnormal termination"}"
  local exit_status="${2:-undefined}"

  # make sure we fail if there are some unexpected stuff in exit_status
  if ! [[ "${exit_status}" =~ ^[0-9]+$ ]]; then
    exit_status=1
  fi

  # making stack trace inside softfail::internal, we dont want to display fail() or softfail() internals in trace
  # so here we start from i=3 (instead of normal i=1) to skip first two lines of stack trace
  log::error_trace "${message}" 3 || echo "Sopka: Unable to log error: ${message}" >&2

  if [ "${exit_status}" != 0 ]; then
    return "${exit_status}"
  fi

  return 1
}

softfail_unless_good::internal() {
  local message="${1:-"Abnormal termination"}"
  local exit_status="${2:-undefined}"

  # make sure we fail if there are some unexpected stuff in exit_status
  if ! [[ "${exit_status}" =~ ^[0-9]+$ ]]; then
    exit_status=1
  fi

  if [ "${exit_status}" != 0 ]; then
    # making stack trace inside softfail::internal, we dont want to display fail() or softfail() internals in trace
    # so here we start from i=3 (instead of normal i=1) to skip first two lines of stack trace
    log::error_trace "${message}" 3 || echo "Sopka: Unable to log error: ${message}" >&2
  fi

  return "${exit_status}"
}

# sopka test::fail-foo; echo exit status: $?

# test::fail-foo() {
#   test::fail-bar
# }

# test::fail-bar() {
#   # fail
#   # fail_code 12
#   # fail "foo" 12
#   # fail_unless_good
#   # fail_unless_good "foo"
#   # fail_unless_good "foo" 12
#   # fail_unless_good "foo" 0
#   # fail_unless_good_code 12
#   # fail_unless_good_code 0

#   # softfail || return $?
#   # softfail_code 12 || return $?
#   # softfail "foo" 12 || return $?
#   # softfail_unless_good || return $?
#   # softfail_unless_good "foo" || return $?
#   # softfail_unless_good "foo" 12 || return $?
#   # softfail_unless_good "foo" 0 || return $?
#   # softfail_unless_good_code 12 || return $?
#   # softfail_unless_good_code 0 || return $?

#   echo end of function!!!
# }

fail::function_sources() {
  cat <<SHELL || softfail || return $?
$(declare -f fail)
$(declare -f fail_code)
$(declare -f fail_unless_good)
$(declare -f fail_unless_good_code)
$(declare -f softfail)
$(declare -f softfail_code)
$(declare -f softfail_unless_good)
$(declare -f softfail_unless_good_code)
$(declare -f softfail::internal)
$(declare -f softfail_unless_good::internal)
SHELL
}
