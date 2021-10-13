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

# note the subshells
# shellcheck disable=SC2030
task::run() {(
  if [ "${SOPKA_TASK_OMIT_TITLE:-}" != true ]; then
    log::notice "Performing '${SOPKA_TASK_TITLE:-"$*"}'..." || fail
  fi

  local tmpFile; tmpFile="$(mktemp)" || fail

  trap "task::cleanup" EXIT

  # I know I could put /dev/fd/0 in variable, but what if system does not support it?
  if [ -t 0 ]; then
    ("$@") </dev/null >"${tmpFile}" 2>"${tmpFile}.stderr"
  else
    ("$@") >"${tmpFile}" 2>"${tmpFile}.stderr"
  fi
  
  local taskResult=$?

  if [ $taskResult = 0 ] && [ "${SOPKA_TASK_FAIL_ON_ERROR_IN_RUBYGEMS:-}" = true ] && grep -q "^ERROR:" "${tmpFile}.stderr"; then
    taskResult=1
  fi

  exit $taskResult
)}

task::stderr-filter() {
  # Those greps are for:
  # 1. ?
  # 2. apt-key
  # 3. git
  # 4. systemd
  grep -vFx "Success." |\
  grep -vFx "Warning: apt-key output should not be parsed (stdout is not a terminal)" |\
  grep -vx "Cloning into '.*'\\.\\.\\." |\
  grep -vx "Created symlink .* → .*\\." |\
  awk NF
  true # TODO: ensure grep exit statuses are good
}

task::is-stderr-empty-after-filtering() {
  # shellcheck disable=2266
  if declare -f "task::stderr-filter" >/dev/null; then
    task::stderr-filter | test "$(wc -c)" = 0
    test "${PIPESTATUS[*]}" = "0 0"
  fi
}

# shellcheck disable=SC2031
task::cleanup() {
  local errorState=0
  local stderrPresent=false

  if [ -s "${tmpFile}.stderr" ]; then
    stderrPresent=true
    if task::is-stderr-empty-after-filtering <"${tmpFile}.stderr"; then
      stderrPresent=false
    fi
  fi

  if [ "${taskResult:-1}" != 0 ] || [ "${stderrPresent}" = true ] || [ "${SOPKA_VERBOSE:-}" = true ] || [ "${SOPKA_VERBOSE_TASKS:-}" = true ]; then

    cat "${tmpFile}" || { echo "Sopka: Unable to display task stdout ($?)" >&2; errorState=1; }

    if [ -s "${tmpFile}.stderr" ]; then
      test -t 2 && terminal::color 9 >&2
      cat "${tmpFile}.stderr" >&2 || { echo "Sopka: Unable to display task stderr ($?)" >&2; errorState=2; }
      test -t 2 && terminal::default-color >&2
    fi
  fi

  if [ "${errorState}" != 0 ]; then
    fail "task::cleanup error state ${errorState}"
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
