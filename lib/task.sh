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

task::run-and-fail-on-errors-in-rubygems() {
  SOPKA_TASKS_FAIL_ON_ERRORS_IN_RUBYGEMS=true task::run "$@"
  test $? = 0 || fail "Error performing ${1:-"(argument is empty)"}"
}

task::run-and-omit-title() {
  SOPKA_TASKS_OMIT_TITLES=true task::run "$@"
  test $? = 0 || fail "Error performing ${1:-"(argument is empty)"}"
}

task::run-with-title() {
  SOPKA_TASK_TITLE="$1" task::run "${@:2}"
  test $? = 0 || fail "Error performing ${1:-"(argument is empty)"}"
}

task::run-verbose() {
  SOPKA_VERBOSE_TASKS=true task::run "$@"
  test $? = 0 || fail "Error performing ${1:-"(argument is empty)"}"
}

task::run() {
  local highlightColor="" errorColor="" normalColor=""
  if terminal::have-16-colors; then 
    highlightColor="$(tput setaf 11)" || fail
    errorColor="$(tput setaf 9)" || fail
    normalColor="$(tput sgr 0)" || fail
  fi

  local tmpFile; tmpFile="$(mktemp)" || fail

  if [ "${SOPKA_TASKS_OMIT_TITLES:-}" != true ]; then
    echo "${highlightColor}Performing ${SOPKA_TASK_TITLE:-$*}...${normalColor}"
  fi

  "$@" </dev/null >"${tmpFile}" 2>"${tmpFile}.stderr"
  local taskResult=$?

  if [ $taskResult = 0 ] && [ "${SOPKA_TASKS_FAIL_ON_ERRORS_IN_RUBYGEMS:-}" = true ] && grep -q "^ERROR:" "${tmpFile}.stderr"; then
    taskResult=1
  fi

  if [ $taskResult != 0 ] || [ -s "${tmpFile}.stderr" ] || [ "${SOPKA_VERBOSE:-}" = true ] || [ "${SOPKA_VERBOSE_TASKS:-}" = true ]; then
    cat "${tmpFile}" || fail

    echo -n "${errorColor}" >&2
    cat "${tmpFile}.stderr" >&2 || fail
    echo -n "${normalColor}" >&2
  fi

  rm "${tmpFile}" "${tmpFile}.stderr" || fail

  return $taskResult
}

# sopka task::run-but-fail-on-rubygems-errors task::test gem

# task::test() {
#   echo hello out1
#   echo hello err1 >&2
#   sleep 1
#   echo hello out2
#   echo hello err2 >&2
#   echo "ERROR: foobar" >&2
#   return 1
# }
