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

task::ssh-jump() {
  # shellcheck disable=2034
  local SOPKA_TASK_SSH_JUMP=true
  "$@"
}

task::run-with-install-filter() {
  # shellcheck disable=2034
  local SOPKA_TASK_STDERR_FILTER=task::install-filter
  task::run "$@"
}

task::run-with-rubygems-fail-detector() {
  # shellcheck disable=2034
  local SOPKA_TASK_FAIL_DETECTOR=task::rubygems-fail-detector
  task::run "$@"
}

task::run-without-title() {
  # shellcheck disable=2034
  local SOPKA_TASK_OMIT_TITLE=true
  task::run "$@"
}

task::run-with-title() {
  # shellcheck disable=2034
  local SOPKA_TASK_TITLE="$1"
  task::run "${@:2}"
}

task::run-with-short-title() {
  # shellcheck disable=2034
  local SOPKA_TASK_TITLE="$1"
  task::run "$@"
}

task::run-verbose() {
  # shellcheck disable=2034
  local SOPKA_TASK_VERBOSE=true
  task::run "$@"
}

task::rubygems-fail-detector() {
  local stderrFile="$2"
  local taskStatus="$3"

  if [ "${taskStatus}" = 0 ] && [ -s "${stderrFile}" ] && grep -q "^ERROR:" "${stderrFile}"; then
    return 1
  fi

  return "${taskStatus}"
}

task::detect-fail-state() {
  local taskStatus="$3"

  if [ -z "${SOPKA_TASK_FAIL_DETECTOR:-}" ]; then
    return "${taskStatus}"
  fi

  "${SOPKA_TASK_FAIL_DETECTOR}" "$@"
}

# note the subshells
task::run() {(
  if [ "${SOPKA_TASK_SSH_JUMP:-}" = true ]; then
    ssh::task "$@"
    return $?
  fi

  if [ "${SOPKA_TASK_OMIT_TITLE:-}" != true ]; then
    log::notice "Performing '${SOPKA_TASK_TITLE:-"$*"}'..." || fail
  fi

  # shellcheck disable=SC2030
  local tempDir; tempDir="$(mktemp -d)" || fail # tempDir also used in task::cleanup signal handler

  trap "task::complete-with-cleanup" EXIT

  # I know I could put /dev/fd/0 in variable, but what if system does not support it?
  if [ -t 0 ]; then # stdin is a terminal
    ("$@") </dev/null >"${tempDir}/stdout" 2>"${tempDir}/stderr"
  else
    ("$@") >"${tempDir}/stdout" 2>"${tempDir}/stderr"
  fi
  
  # shellcheck disable=SC2030
  local taskStatus=$? # taskStatus also used in task::cleanup signal handler so we must assign it here

  task::detect-fail-state "${tempDir}/stdout" "${tempDir}/stderr" "${taskStatus}"
  local taskStatus=$? # taskStatus also used in task::cleanup signal handler so we must assign it here

  exit "${taskStatus}"
)}

task::install-filter() {
  # Those greps are for:
  # 1. tailscale
  # 2. apt-key
  # 3. git

  grep -vFx "Success." |\
  grep -vFx "Warning: apt-key output should not be parsed (stdout is not a terminal)" |\
  grep -vx "Cloning into '.*'\\.\\.\\."

  if ! [[ "${PIPESTATUS[*]}" =~ ^([01][[:blank:]])*[01]$ ]]; then
    softfail || return $?
  fi
}

task::is-stderr-empty-after-filtering() {
  local stderrFile="$1"

  local stderrSize; stderrSize="$("${SOPKA_TASK_STDERR_FILTER}" <"${stderrFile}" | awk NF | wc -c; test "${PIPESTATUS[*]}" = "0 0 0")" || softfail || return $?

  if [ "${stderrSize}" != 0 ]; then
    return 1
  fi
}

# shellcheck disable=SC2031
task::complete-with-cleanup() {
  task::complete || softfail || return $?

  if [ "${SOPKA_TASK_KEEP_TEMP_FILES:-}" != true ]; then
    rm -fd "${tempDir}/stdout" "${tempDir}/stderr" "${tempDir}" || softfail || return $?
  fi
}

# shellcheck disable=SC2031
task::complete() {
  local errorState=0
  local stderrPresent=false

  if [ "${taskStatus:-1}" = 0 ] && [ -s "${tempDir}/stderr" ]; then
    stderrPresent=true
    if [ -n "${SOPKA_TASK_STDERR_FILTER:-}" ] && task::is-stderr-empty-after-filtering "${tempDir}/stderr"; then
      stderrPresent=false
    fi
  fi

  if [ "${taskStatus:-1}" != 0 ] || [ "${stderrPresent}" = true ] || [ "${SOPKA_VERBOSE:-}" = true ] || [ "${SOPKA_TASK_VERBOSE:-}" = true ]; then

    if [ -s "${tempDir}/stdout" ]; then
      cat "${tempDir}/stdout" || { echo "Sopka: Unable to display task stdout ($?)" >&2; errorState=1; }
    fi

    if [ -s "${tempDir}/stderr" ]; then
      test -t 2 && terminal::color 9 >&2
      cat "${tempDir}/stderr" >&2 || { echo "Sopka: Unable to display task stderr ($?)" >&2; errorState=2; }
      test -t 2 && terminal::default-color >&2
    fi
  fi

  if [ "${errorState}" != 0 ]; then
    softfail "task::cleanup error state ${errorState}" || return $?
  fi
}

# weird stuff
# -----------
# onexit() {
#   echo hello
#   cat out
#   cat err
# }
#
# trap "onexit" EXIT
#
# thing() {
#   echo ok
#   sleep 30
# }
#
# (thing) </dev/null >out >err
