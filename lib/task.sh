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

# shellcheck disable=SC2030
task::run() {(
  local fail_detector
  local task_title
  local short_title=false
  local omit_title=false

  # Those_Variables are used in other functions down the call stack and in signal handlers
  local Stderr_Filter
  local Keep_Temp_Files
  local Verbose_Output

  while [[ "$#" -gt 0 ]]; do
    case $1 in
    -e|--stderr-filter)
      Stderr_Filter="$2"
      shift; shift
      ;;
    -i|--install-filter)
      Stderr_Filter=task::install_filter
      shift
      ;;
    -f|--fail-detector)
      fail_detector="$2"
      shift; shift
      ;;
    -r|--rubygems-fail-detector)
      fail_detector=task::rubygems_fail_detector
      shift
      ;;
    -t|--title)
      task_title="$2"
      shift; shift
      ;;
    -s|--short-title)
      short_title=true
      shift
      ;;
    -o|--omit-title)
      omit_title=true
      shift
      ;;
    -k|--keep-temp-files)
      Keep_Temp_Files=true
      shift
      ;;
    -v|--verbose)
      Verbose_Output=true
      shift
      ;;
    -*)
      softfail "Unknown argument: $1" || return $?
      ;;
    *)
      break
      ;;
    esac
  done

  if [ "${short_title}" = true ]; then
    task_title="$1"
  fi

  if [ "${omit_title}" != true ] && [ "${RUNAG_TASK_OMIT_TITLE:-}" != true ]; then
    log::notice "Performing '${task_title:-"$*"}'..." || softfail || return $?
  fi
  
  local Temp_Dir; Temp_Dir="$(mktemp -d)" || softfail || return $?
  local Task_Status

  trap "task::complete_with_cleanup" EXIT

  # I know I could put /dev/fd/0 in variable, but what if system does not support it?
  if [ -t 0 ]; then # check if stdin is a terminal
    ("$@") </dev/null >"${Temp_Dir}/stdout" 2>"${Temp_Dir}/stderr"
  else
    ("$@") >"${Temp_Dir}/stdout" 2>"${Temp_Dir}/stderr"
  fi

  task::detect_fail_state "${Temp_Dir}/stdout" "${Temp_Dir}/stderr" $? "${fail_detector:-}"
  
  Task_Status=$?

  exit "${Task_Status}"
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

task::detect_fail_state() {
  # local stdout_file="$1"
  # local stderr_file="$2"
  local task_status="$3"
  local fail_detector="$4"

  if [ -z "${fail_detector:-"${RUNAG_TASK_FAIL_DETECTOR:-}"}" ]; then
    return "${task_status}"
  fi

  "${fail_detector:-"${RUNAG_TASK_FAIL_DETECTOR:-}"}" "$@"
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
  local error_state=false
  local stderr_present=false

  if [ "${Task_Status:-1}" = 0 ] && [ -s "${Temp_Dir}/stderr" ]; then
    stderr_present=true
    if [ -n "${Stderr_Filter:-"${RUNAG_TASK_STDERR_FILTER:-}"}" ]; then
      local stderr_size; stderr_size="$("${Stderr_Filter:-"${RUNAG_TASK_STDERR_FILTER}"}" <"${Temp_Dir}/stderr" | awk NF | wc -c; test "${PIPESTATUS[*]}" = "0 0 0")" || softfail "Error performing STDERR filter" || return $?
      if [ "${stderr_size}" = 0 ]; then
        stderr_present=false
      fi
    fi
  fi

  if [ "${Task_Status:-1}" != 0 ] || [ "${stderr_present}" = true ] || [ "${Verbose_Output:-}" = true ] || [ "${RUNAG_VERBOSE:-}" = true ] || [ "${RUNAG_TASK_VERBOSE:-}" = true ]; then

    if [ -s "${Temp_Dir}/stdout" ]; then
      cat "${Temp_Dir}/stdout" || { echo "Unable to display task stdout ($?)" >&2; error_state=true; }
    fi

    if [ -s "${Temp_Dir}/stderr" ]; then
      local terminal_sequence

      if [ -t 2 ] && terminal_sequence="$(tput setaf 9 2>/dev/null)"; then
        echo -n "${terminal_sequence}" >&2
      fi

      cat "${Temp_Dir}/stderr" >&2 || { echo "Unable to display task stderr ($?)" >&2; error_state=true; }

      if [ -t 2 ] && terminal_sequence="$(tput sgr 0 2>/dev/null)"; then
        echo -n "${terminal_sequence}" >&2
      fi
    fi
  fi

  if [ "${error_state}" = true ]; then
    softfail "Error reading STDOUT/STDERR in task::complete" || return $?
  fi
}

# shellcheck disable=SC2031
task::complete_with_cleanup() {
  task::complete || softfail || return $?

  if [ "${Keep_Temp_Files:-"${RUNAG_TASK_KEEP_TEMP_FILES:-}"}" != true ]; then
    rm -fd "${Temp_Dir}/stdout" "${Temp_Dir}/stderr" "${Temp_Dir}" || softfail || return $?
  fi
}

task::function_sources() {
  cat <<SHELL || softfail || return $?
$(declare -f task::run)
$(declare -f task::install_filter)
$(declare -f task::detect_fail_state)
$(declare -f task::rubygems_fail_detector)
$(declare -f task::complete)
$(declare -f task::complete_with_cleanup)
SHELL
}
