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

benchmark::run() {
  local hostname_string; hostname_string="$(hostnamectl --static status)" || softfail || return $?
  local current_date; current_date="$(date --utc "+%Y-%m-%dT%H%M%SZ")" || softfail || return $?

  local result_file; result_file="$(mktemp "benchmark-${hostname_string}-${current_date}-XXX.txt")" || softfail || return $?

  benchmark::run::indeed | tee "${result_file}"
  test "${PIPESTATUS[*]}" = "0 0" || softfail || return $?
}

benchmark::run::indeed() (
  echo "## CPU SPEED ##"
  sysbench cpu run || softfail || return $?

  echo "## THREADS ##"
  sysbench threads run || softfail || return $?

  echo "## RAM WRITE, 4KiB BLOCKS ##"
  sysbench memory run --memory-block-size=4096 || softfail || return $?

  local temp_dir; temp_dir="$(mktemp -d "${HOME}/.benchmark-XXXXXX")" || softfail || return $?

  cd "${temp_dir}" || softfail || return $?

  sysbench fileio prepare --verbosity=2 --file-extra-flags=direct || softfail || return $?

  echo "## RANDOM READ QD1 ##"
  sysbench fileio run --file-test-mode=rndrd --file-block-size=4096 --file-extra-flags=direct || softfail || return $?

  echo "## RANDOM WRITE QD1 ##"
  sysbench fileio run --file-test-mode=rndwr --file-block-size=4096 --file-fsync-freq=0 --file-fsync-end=on --file-extra-flags=direct || softfail || return $?

  if ! [[ "${OSTYPE}" =~ ^darwin ]]; then
    echo "## RANDOM READ QD32 ##"
    sysbench fileio run --file-test-mode=rndrd --file-block-size=4096 --file-io-mode=async --file-async-backlog=32 || softfail || return $?

    echo "## RANDOM WRITE QD32 ##"
    sysbench fileio run --file-test-mode=rndwr --file-block-size=4096 --file-fsync-freq=0 --file-fsync-end=on --file-io-mode=async --file-async-backlog=32 || softfail || return $?
  fi

  echo "## SEQUENTIAL READ ##"
  sysbench fileio run --file-test-mode=seqrd --file-block-size=4096 --file-extra-flags=direct || softfail || return $?

  # this should be final tests as they truncate files
  echo "## SEQUENTIAL WRITE ##"
  sysbench fileio run --file-test-mode=seqwr --file-block-size=4096 --file-fsync-freq=0 --file-fsync-end=on --file-extra-flags=direct || softfail || return $?

  echo "## SEQUENTIAL WRITE IN SYNC MODE ##"
  sysbench fileio run --file-test-mode=seqwr --file-block-size=4096 --file-extra-flags=sync --file-fsync-freq=0 --file-fsync-end=on --file-extra-flags=direct || softfail || return $?

  sysbench fileio cleanup --verbosity=2 || softfail || return $?

  rmdir "${temp_dir}" || softfail || return $?
)
