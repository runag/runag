#!/usr/bin/env bash

#  Copyright 2012-2022 Stanislav Senotrusov <stan@senotrusov.com>
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
  local hostname_string; hostname_string="$(os::hostname)" || fail
  local current_date; current_date="$(date +"%Y-%m-%d %H-%M-%S")" || fail

  local result_file; result_file="$(mktemp -u "${HOME}/sopka-benchmark ${hostname_string} ${current_date} XXXXXXXXXX")" || fail

  benchmark::actually_run "${result_file}.txt" || fail

  echo "${result_file}.txt"
}

benchmark::actually_run() {
  local result_file="$1"

  echo "### CPU SPEED ###" >> "${result_file}"
  sysbench cpu run >> "${result_file}" || fail

  echo "### THREADS ###" >> "${result_file}"
  sysbench threads run >> "${result_file}" || fail

  echo "### RAM WRITE, 4KiB BLOCKS ###" >> "${result_file}"
  sysbench memory run --memory-block-size=4096 >> "${result_file}" || fail

  (
    local temp_dir; temp_dir="$(mktemp -d "${HOME}/sopka-benchmark-XXXXXXXXXX")" || fail
    cd "${temp_dir}" || fail

    benchmark::fileio "${result_file}" || fail
    benchmark::fileio "${result_file}" --file-extra-flags=direct || fail

    rmdir "${temp_dir}" || fail
  ) || fail
}

# shellcheck disable=SC2086
benchmark::fileio() {
  local result_file="$1"

  sysbench fileio prepare --verbosity=2 ${2:-} || fail

  echo "### SEQUENTIAL READ ${2:-} ###" >> "${result_file}"
  sysbench fileio run --file-test-mode=seqrd --file-block-size=4096 ${2:-} >> "${result_file}" || fail

  echo "### RANDOM READ QD1 ${2:-} ###" >> "${result_file}"
  sysbench fileio run --file-test-mode=rndrd --file-block-size=4096 ${2:-} >> "${result_file}" || fail

  if ! [[ "${OSTYPE}" =~ ^darwin ]]; then
    echo "### RANDOM READ QD32 ${2:-} ###" >> "${result_file}"
    sysbench fileio run --file-test-mode=rndrd --file-block-size=4096 --file-io-mode=async --file-async-backlog=32 ${2:-} >> "${result_file}" || fail
  fi

  echo "### RANDOM WRITE QD1 ${2:-} ###" >> "${result_file}"
  sysbench fileio run --file-test-mode=rndwr --file-block-size=4096 --file-fsync-freq=0 --file-fsync-end=on ${2:-} >> "${result_file}" || fail

  if ! [[ "${OSTYPE}" =~ ^darwin ]]; then
    echo "### RANDOM WRITE QD32 ${2:-} ###" >> "${result_file}"
    sysbench fileio run --file-test-mode=rndwr --file-block-size=4096 --file-fsync-freq=0 --file-fsync-end=on --file-io-mode=async --file-async-backlog=32 ${2:-} >> "${result_file}" || fail
  fi

  # this should be final tests as they truncate files
  echo "### SEQUENTIAL WRITE ${2:-} ###" >> "${result_file}"
  sysbench fileio run --file-test-mode=seqwr --file-block-size=4096 --file-fsync-freq=0 --file-fsync-end=on ${2:-} >> "${result_file}" || fail

  echo "### SEQUENTIAL WRITE IN SYNC MODE ${2:-} ###" >> "${result_file}"
  sysbench fileio run --file-test-mode=seqwr --file-block-size=4096 --file-extra-flags=sync --file-fsync-freq=0 --file-fsync-end=on ${2:-} >> "${result_file}" || fail

  sysbench fileio cleanup --verbosity=2 || fail
}
