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
  local trace_start=1
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
      trace_start=2
      shift
      ;;
    -*)
      { declare -F "log::error" >/dev/null && log::error "Unknown argument for fail: $1"; } || echo "Unknown argument for fail: $1" >&2
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

  { declare -F "log::error" >/dev/null && log::error "${message}"; } || echo "${message}" >&2

  local trace_line trace_index trace_end=$((${#BASH_LINENO[@]}-1))
  for ((trace_index=trace_start; trace_index<=trace_end; trace_index++)); do
    trace_line="  ${BASH_SOURCE[${trace_index}]}:${BASH_LINENO[$((trace_index-1))]}: in \`${FUNCNAME[${trace_index}]}'"
    { declare -F "log::error" >/dev/null && log::error "${trace_line}"; } || echo "${trace_line}" >&2
  done

  if [ "${perform_softfail}" = true ]; then
    return "${exit_status}"
  fi

  exit "${exit_status}"
}

softfail() {
  fail --wrapped-softfail "$@"
}

fail::function_sources() {
  cat <<SHELL || softfail || return $?
$(declare -f fail)
$(declare -f softfail)
SHELL
}
