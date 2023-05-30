#!/usr/bin/env bash

#  Copyright 2012-2022 Rùnag project contributors
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

task::with_task_verbose() {(
  export RUNAG_TASK_VERBOSE=true
  "$@"
)}

task::ssh_jump() {
  # shellcheck disable=2034
  local RUNAG_TASK_SSH_JUMP=true
  "$@"
}

task::run_with_install_filter() {
  # shellcheck disable=2034
  local RUNAG_TASK_STDERR_FILTER=task::install_filter
  task::run "$@"
}

task::run_with_rubygems_fail_detector() {
  # shellcheck disable=2034
  local RUNAG_TASK_FAIL_DETECTOR=task::rubygems_fail_detector
  task::run "$@"
}

task::run_without_title() {
  # shellcheck disable=2034
  local RUNAG_TASK_OMIT_TITLE=true
  task::run "$@"
}

task::run_with_title() {
  # shellcheck disable=2034
  local RUNAG_TASK_TITLE="$1"
  task::run "${@:2}"
}

task::run_with_short_title() {
  # shellcheck disable=2034
  local RUNAG_TASK_TITLE="$1"
  task::run "$@"
}

task::run_verbose() {
  # shellcheck disable=2034
  local RUNAG_TASK_VERBOSE=true
  task::run "$@"
}

# shellcheck disable=SC2030
task::run() {(
  if [ "${RUNAG_TASK_SSH_JUMP:-}" = true ]; then
    ssh::task "$@"
    return $?
  fi

  if [ "${RUNAG_TASK_OMIT_TITLE:-}" != true ]; then
    log::notice "Performing '${RUNAG_TASK_TITLE:-"$*"}'..." || softfail || return $?
  fi
  
  local temp_dir; temp_dir="$(mktemp -d)" || softfail || return $? # temp_dir also used in task::cleanup signal handler

  trap "task::complete_with_cleanup" EXIT

  # I know I could put /dev/fd/0 in variable, but what if system does not support it?
  if [ -t 0 ]; then # stdin is a terminal
    ("$@") </dev/null >"${temp_dir}/stdout" 2>"${temp_dir}/stderr"
  else
    ("$@") >"${temp_dir}/stdout" 2>"${temp_dir}/stderr"
  fi
  
  local task_status=$? # task_status also used in task::cleanup signal handler so we must assign it here

  task::detect_fail_state "${temp_dir}/stdout" "${temp_dir}/stderr" "${task_status}"
  local task_status=$? # task_status also used in task::cleanup signal handler so we must assign it here

  exit "${task_status}"
)}

task::install_filter() {
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

task::is_stderr_empty_after_filtering() {
  local stderr_file="$1"

  local stderr_size; stderr_size="$("${RUNAG_TASK_STDERR_FILTER}" <"${stderr_file}" | awk NF | wc -c; test "${PIPESTATUS[*]}" = "0 0 0")" || fail # no softfail here!

  if [ "${stderr_size}" != 0 ]; then
    return 1
  fi
}

task::detect_fail_state() {
  local task_status="$3"

  if [ -z "${RUNAG_TASK_FAIL_DETECTOR:-}" ]; then
    return "${task_status}"
  fi

  "${RUNAG_TASK_FAIL_DETECTOR}" "$@"
}

task::rubygems_fail_detector() {
  local stderr_file="$2"
  local task_status="$3"

  if [ "${task_status}" = 0 ] && [ -s "${stderr_file}" ] && grep -q "^ERROR:" "${stderr_file}"; then
    return 1
  fi

  return "${task_status}"
}

# shellcheck disable=SC2031
task::complete() {
  local error_state=0
  local stderr_present=false

  if [ "${task_status:-1}" = 0 ] && [ -s "${temp_dir}/stderr" ]; then
    stderr_present=true
    if [ -n "${RUNAG_TASK_STDERR_FILTER:-}" ] && task::is_stderr_empty_after_filtering "${temp_dir}/stderr"; then
      stderr_present=false
    fi
  fi

  if [ "${task_status:-1}" != 0 ] || [ "${stderr_present}" = true ] || [ "${RUNAG_VERBOSE:-}" = true ] || [ "${RUNAG_TASK_VERBOSE:-}" = true ]; then

    if [ -s "${temp_dir}/stdout" ]; then
      cat "${temp_dir}/stdout" || { echo "Unable to display task stdout ($?)" >&2; error_state=1; }
    fi

    if [ -s "${temp_dir}/stderr" ]; then
      test -t 2 && terminal::color --foreground 9 >&2
      cat "${temp_dir}/stderr" >&2 || { echo "Unable to display task stderr ($?)" >&2; error_state=2; }
      test -t 2 && terminal::default_color >&2
    fi
  fi

  if [ "${error_state}" != 0 ]; then
    softfail "task::cleanup error state ${error_state}" || return $?
  fi
}

# shellcheck disable=SC2031
task::complete_with_cleanup() {
  task::complete || softfail || return $?

  if [ "${RUNAG_TASK_KEEP_TEMP_FILES:-}" != true ]; then
    rm -fd "${temp_dir}/stdout" "${temp_dir}/stderr" "${temp_dir}" || softfail || return $?
  fi
}

task::function_sources() {
  cat <<SHELL || softfail || return $?
$(declare -f task::with_task_verbose)
$(declare -f task::ssh_jump)
$(declare -f task::run_with_install_filter)
$(declare -f task::run_with_rubygems_fail_detector)
$(declare -f task::run_without_title)
$(declare -f task::run_with_title)
$(declare -f task::run_with_short_title)
$(declare -f task::run_verbose)
$(declare -f task::run)
$(declare -f task::install_filter)
$(declare -f task::is_stderr_empty_after_filtering)
$(declare -f task::detect_fail_state)
$(declare -f task::rubygems_fail_detector)
$(declare -f task::complete)
$(declare -f task::complete_with_cleanup)
SHELL
}
