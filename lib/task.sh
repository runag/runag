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

task::run-and-fail-on-error-in-rubygems() {
  SOPKA_TASK_FAIL_ON_ERROR_IN_RUBYGEMS=true task::run "$@"
}

task::run-and-omit-title() {
  SOPKA_TASK_OMIT_TITLE=true task::run "$@"
}

task::run-with-title() {
  SOPKA_TASK_TITLE="$1" task::run "${@:2}"
}

task::run-with-short-title() {
  SOPKA_TASK_TITLE="$1" task::run "$@"
}

task::run-verbose() {
  SOPKA_VERBOSE_TASKS=true task::run "$@"
}

# note the subshell
# shellcheck disable=SC2030
task::run() {(
  local highlightColor="" errorColor="" normalColor=""
  if terminal::have-16-colors; then 
    highlightColor="$(tput setaf 11)" || fail
    errorColor="$(tput setaf 9)" || fail
    normalColor="$(tput sgr 0)" || fail
  fi

  if [ "${SOPKA_TASK_OMIT_TITLE:-}" != true ]; then
    echo "${highlightColor}Performing ${SOPKA_TASK_TITLE:-$*}...${normalColor}"
  fi

  local tmpFile="$(mktemp)" || fail

  trap "task::cleanup" EXIT

  ("$@") </dev/null >"${tmpFile}" 2>"${tmpFile}.stderr"
  local taskResult=$?

  if [ $taskResult = 0 ] && [ "${SOPKA_TASK_FAIL_ON_ERROR_IN_RUBYGEMS:-}" = true ] && grep -q "^ERROR:" "${tmpFile}.stderr"; then
    taskResult=1
  fi

  exit $taskResult
)}

task::stderr-filter() {
  grep -vFx "Success." |\
  grep -vFx "Warning: apt-key output should not be parsed (stdout is not a terminal)" |\
  grep -vx "Cloning into '.*'\\.\\.\\." |\
  grep -vx "Created symlink .* → .*\\."
  true # TODO: ensure grep exit statuses are good?
}

# shellcheck disable=SC2031
task::cleanup() {
  local stderrPresent=false

  if [ -s "${tmpFile}.stderr" ]; then
    if declare -f "task::stderr-filter" >/dev/null; then
      local lineCount; lineCount="$(task::stderr-filter < "${tmpFile}.stderr" | wc -l; test "${PIPESTATUS[*]}" = "0 0")" || fail
      if [ "${lineCount}" = 0 ]; then
        stderrPresent=false
      else
        stderrPresent=true
      fi
    else
      stderrPresent=true
    fi
  fi

  if [ "${taskResult:-1}" != 0 ] || [ "${stderrPresent}" = true ] || [ "${SOPKA_VERBOSE:-}" = true ] || [ "${SOPKA_VERBOSE_TASKS:-}" = true ]; then
    cat "${tmpFile}" || fail

    if [ -s "${tmpFile}.stderr" ]; then
      echo -n "${errorColor}" >&2
      cat "${tmpFile}.stderr" >&2 || fail
      echo -n "${normalColor}" >&2
    fi
  fi

  rm "${tmpFile}" || fail
  rm -f "${tmpFile}.stderr" || fail
}

# weird stuff
# -----------
# onexit(){
#   echo hello
#   cat out
#   cat err
# }
#
# trap "onexit" EXIT
#
# thing(){
#   echo ok
#   sleep 30
# }
#
# (thing) </dev/null >out >err
