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

# fail --code $? --unless-good "msg"
# softfail --code $? --unless-good "msg"

fail() {
  local exit_status=""
  local unless_good=false
  local perform_softfail=false
  local trace_start=2
  local message=""

  while [[ "$#" -gt 0 ]]; do
    case $1 in
    -c|--code)
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
    --wrapped-softfail)
      perform_softfail=true
      trace_start=3
      shift
      ;;
    -*)
      log::error "Unknown argument for fail: $1" || echo "(unable to log by usual means) Unknown argument for fail: $1" >&2
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

  # making stack trace inside fail, we dont want to display fail() or softfail() internals in trace
  # so here we may start from trace_start=3 (instead of normal trace_start=1) to skip first two lines of stack trace
  log::trace --start "${trace_start}" "${message}" || echo "Unable to log error: ${message}" >&2

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
