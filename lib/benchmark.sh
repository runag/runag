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

benchmark::is-available() {
  if [[ "${OSTYPE}" =~ ^linux ]] || [[ "${OSTYPE}" =~ ^darwin ]]; then
    if command -v sysbench >/dev/null; then
      return 0
    fi
  fi
  return 1
}

benchmark::run() {
  local hostnameString; hostnameString="$(hostname)" || fail
  local currentDate; currentDate="$(date +"%Y-%m-%d %H-%M-%S")" || fail

  local resultFile; resultFile="$(mktemp -u "${HOME}/sopka-benchmark ${hostnameString} ${currentDate} XXXXXXXXXX")" || fail

  benchmark::actually-run | tee "${resultFile}.txt" >/dev/null
  test "${PIPESTATUS[*]}" = "0 0" || fail

  echo "${resultFile}.txt"
}

benchmark::actually-run() {
  echo "### CPU SPEED ###"
  sysbench cpu run || fail

  echo "### THREADS ###"
  sysbench threads run || fail

  echo "### RAM WRITE, 4KiB BLOCKS ###"
  sysbench memory run --memory-block-size=4096 || fail

  (
    local tempDir; tempDir="$(mktemp -d "${HOME}/sopka-benchmark-XXXXXXXXXX")" || fail
    cd "${tempDir}" || fail
    benchmark::fileio || fail
    benchmark::fileio --file-extra-flags=direct || fail
    rmdir "${tempDir}" || fail
  ) || fail
}

benchmark::fileio() {
  sysbench fileio prepare ${1:-} >/dev/null || fail

  echo "### SEQUENTIAL READ ${1:-} ###"
  sysbench fileio run --file-test-mode=seqrd --file-block-size=4096 ${1:-} || fail

  echo "### RANDOM READ QD1 ${1:-} ###"
  sysbench fileio run --file-test-mode=rndrd --file-block-size=4096 ${1:-} || fail

  if ! [[ "${OSTYPE}" =~ ^darwin ]]; then
    echo "### RANDOM READ QD32 ${1:-} ###"
    sysbench fileio run --file-test-mode=rndrd --file-block-size=4096 --file-io-mode=async --file-async-backlog=32 ${1:-} || fail
  fi

  echo "### RANDOM WRITE QD1 ${1:-} ###"
  sysbench fileio run --file-test-mode=rndwr --file-block-size=4096 --file-fsync-freq=0 --file-fsync-end=on ${1:-} || fail

  if ! [[ "${OSTYPE}" =~ ^darwin ]]; then
    echo "### RANDOM WRITE QD32 ${1:-} ###"
    sysbench fileio run --file-test-mode=rndwr --file-block-size=4096 --file-fsync-freq=0 --file-fsync-end=on --file-io-mode=async --file-async-backlog=32 ${1:-} || fail
  fi

  # this should be final tests as they truncate files
  echo "### SEQUENTIAL WRITE ${1:-} ###"
  sysbench fileio run --file-test-mode=seqwr --file-block-size=4096 --file-fsync-freq=0 --file-fsync-end=on ${1:-} || fail

  echo "### SEQUENTIAL WRITE IN SYNC MODE ${1:-} ###"
  sysbench fileio run --file-test-mode=seqwr --file-block-size=4096 --file-extra-flags=sync --file-fsync-freq=0 --file-fsync-end=on ${1:-} || fail

  sysbench fileio cleanup >/dev/null || fail
}
