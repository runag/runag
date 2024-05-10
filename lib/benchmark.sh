#!/usr/bin/env bash

#  Copyright 2012-2024 Rùnag project contributors
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

benchmark::is_available() {
  if [[ "${OSTYPE}" =~ ^linux ]] || [[ "${OSTYPE}" =~ ^darwin ]]; then
    if command -v sysbench >/dev/null; then
      return 0
    fi
  fi
  return 1
}

benchmark::install::apt() {
  apt::install sysbench || softfail || return $?
}

benchmark::run() {
  local hostname_string; hostname_string="$(os::hostname)" || softfail || return $?
  local current_date; current_date="$(date --utc "+%Y%m%dT%H%M%SZ")" || softfail || return $?

  local result_file; result_file="$(mktemp -u "${HOME}/benchmark ${hostname_string} ${current_date} XXXXXXXXXX")" || softfail || return $?

  benchmark::actually_run "${result_file}.txt" || softfail || return $?

  echo "${result_file}.txt"
}

benchmark::actually_run() {
  local result_file="$1"

  echo "### CPU SPEED ###" >> "${result_file}"
  sysbench cpu run >> "${result_file}" || softfail || return $?

  echo "### THREADS ###" >> "${result_file}"
  sysbench threads run >> "${result_file}" || softfail || return $?

  echo "### RAM WRITE, 4KiB BLOCKS ###" >> "${result_file}"
  sysbench memory run --memory-block-size=4096 >> "${result_file}" || softfail || return $?

  (
    local temp_dir; temp_dir="$(mktemp -d "${HOME}/benchmark-XXXXXXXXXX")" || softfail || return $?
    cd "${temp_dir}" || softfail || return $?

    benchmark::fileio "${result_file}" || softfail || return $?
    benchmark::fileio "${result_file}" --file-extra-flags=direct || softfail || return $?

    rmdir "${temp_dir}" || softfail || return $?
  ) || softfail || return $?
}

# shellcheck disable=SC2086
benchmark::fileio() {
  local result_file="$1"

  sysbench fileio prepare --verbosity=2 ${2:-} || softfail || return $?

  echo "### SEQUENTIAL READ ${2:-} ###" >> "${result_file}"
  sysbench fileio run --file-test-mode=seqrd --file-block-size=4096 ${2:-} >> "${result_file}" || softfail || return $?

  echo "### RANDOM READ QD1 ${2:-} ###" >> "${result_file}"
  sysbench fileio run --file-test-mode=rndrd --file-block-size=4096 ${2:-} >> "${result_file}" || softfail || return $?

  if ! [[ "${OSTYPE}" =~ ^darwin ]]; then
    echo "### RANDOM READ QD32 ${2:-} ###" >> "${result_file}"
    sysbench fileio run --file-test-mode=rndrd --file-block-size=4096 --file-io-mode=async --file-async-backlog=32 ${2:-} >> "${result_file}" || softfail || return $?
  fi

  echo "### RANDOM WRITE QD1 ${2:-} ###" >> "${result_file}"
  sysbench fileio run --file-test-mode=rndwr --file-block-size=4096 --file-fsync-freq=0 --file-fsync-end=on ${2:-} >> "${result_file}" || softfail || return $?

  if ! [[ "${OSTYPE}" =~ ^darwin ]]; then
    echo "### RANDOM WRITE QD32 ${2:-} ###" >> "${result_file}"
    sysbench fileio run --file-test-mode=rndwr --file-block-size=4096 --file-fsync-freq=0 --file-fsync-end=on --file-io-mode=async --file-async-backlog=32 ${2:-} >> "${result_file}" || softfail || return $?
  fi

  # this should be final tests as they truncate files
  echo "### SEQUENTIAL WRITE ${2:-} ###" >> "${result_file}"
  sysbench fileio run --file-test-mode=seqwr --file-block-size=4096 --file-fsync-freq=0 --file-fsync-end=on ${2:-} >> "${result_file}" || softfail || return $?

  echo "### SEQUENTIAL WRITE IN SYNC MODE ${2:-} ###" >> "${result_file}"
  sysbench fileio run --file-test-mode=seqwr --file-block-size=4096 --file-extra-flags=sync --file-fsync-freq=0 --file-fsync-end=on ${2:-} >> "${result_file}" || softfail || return $?

  sysbench fileio cleanup --verbosity=2 || softfail || return $?
}
