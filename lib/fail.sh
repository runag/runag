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

# fail --exit-status $? --unless-good "msg"
# softfail --exit-status $? --unless-good "msg"

fail() {
  local exit_status=""
  local unless_good=false
  local perform_softfail=false
  local trace_start=2
  local message=""

  while [[ "$#" -gt 0 ]]; do
    case $1 in
    -e|--exit-status)
      exit_status="$2"
      shift; shift
      ;;
    -u|--unless-good)
      unless_good=true
      shift
      ;;
    -s|--soft)
      perform_softfail=true
      shift
      ;;
    -w|--wrapped-softfail)
      perform_softfail=true
      trace_start=3
      shift
      ;;
    -*)
      { declare -f "log::error" >/dev/null && log::error "Unknown argument for fail: $1"; } || echo "Unknown argument for fail: $1" >&2
      shift
      message="$*"
      break
      ;;
    *)
      message="$1"
      break
      ;;
    esac
  done

  if [ -z "${message}" ]; then
    message="Abnormal termination"
  fi

  # make sure we fail if there are some unexpected stuff in exit_status
  if ! [[ "${exit_status}" =~ ^[0-9]+$ ]]; then
    exit_status=1
  elif [ "${exit_status}" = 0 ]; then
    if [ "${unless_good}" = true ]; then
      return 0
    fi
    exit_status=1
  fi

  { declare -f "log::error" >/dev/null && log::error "${message}"; } || echo "${message}" >&2

  # making stack trace inside fail, we dont want to display fail() or softfail() internals in trace
  # so here we may start from trace_start = 2 or 3 (instead of normal trace_start=1) to skip first two lines of stack trace
  fail::trace --start "${trace_start}" || echo "Unable to log stack trace" >&2

  if [ "${perform_softfail}" = true ]; then
    return "${exit_status}"
  fi

  exit "${exit_status}"
}

fail::trace() {
  local trace_start=1

  while [[ "$#" -gt 0 ]]; do
    case $1 in
    -s|--start)
      trace_start="$2"
      shift; shift
      ;;
    *)
      { declare -f "log::error" >/dev/null && log::error "Unknown argument for fail::trace: $1"; } || echo "Unknown argument for fail::trace: $1" >&2
      break
      ;;
    esac
  done

  local line i trace_end=$((${#BASH_LINENO[@]}-1))
  for ((i=trace_start; i<=trace_end; i++)); do
    line="  ${BASH_SOURCE[${i}]}:${BASH_LINENO[$((i-1))]}: in \`${FUNCNAME[${i}]}'"
    { declare -f "log::error" >/dev/null && log::error "${line}"; } || echo "${line}" >&2
  done
}

softfail() {
  fail --wrapped-softfail "$@"
}

fail::function_sources() {
  cat <<SHELL || softfail || return $?
$(declare -f fail)
$(declare -f fail::trace)
$(declare -f softfail)
SHELL
}
