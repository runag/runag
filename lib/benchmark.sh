#!/usr/bin/env bash

#  Copyright 2012-2019 Stanislav Senotrusov <stan@senotrusov.com>
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

benchmark() {
  local current_date; current_date="$(date +"%Y-%m-%d %H-%M-%S")" || fail
  local hostname_string; hostname_string="$(hostname)" || fail

  benchmark::run | tee "${HOME}/${hostname_string} ${current_date} benchmark.txt"
  test "${PIPESTATUS[*]}" = "0 0" || fail
}

benchmark::run() (
  mkdir "${HOME}/.sysbench" || fail
  cd "${HOME}/.sysbench" || fail

  echo "### CPU SPEED ###"
  sysbench cpu run || fail

  echo "### THREADS ###"
  sysbench threads run || fail

  echo "### RAM WRITE, 4KiB BLOCKS ###"
  sysbench memory run --memory-block-size=4096 || fail

  sysbench fileio prepare --file-extra-flags=sync || fail

  echo "### SEQUENTIAL READ ###"
  sysbench fileio run --file-test-mode=seqrd --file-block-size=4096 --file-extra-flags=sync --file-fsync-freq=0 --file-fsync-end=off || fail

  echo "### RANDOM READ QD1 ###"
  sysbench fileio run --file-test-mode=rndrd --file-block-size=4096 --file-extra-flags=sync --file-fsync-freq=0 --file-fsync-end=off || fail

  if ! [[ "$OSTYPE" =~ ^darwin ]]; then
    echo "### RANDOM READ QD32 ###"
    sysbench fileio run --file-test-mode=rndrd --file-block-size=4096 --file-extra-flags=sync --file-fsync-freq=0 --file-fsync-end=off --file-io-mode=async --file-async-backlog=32 || fail
  fi

  echo "### RANDOM WRITE FSYNC EVERY 100 REQ QD1 ###"
  sysbench fileio run --file-test-mode=rndwr --file-block-size=4096 --file-extra-flags=sync || fail

  echo "### RANDOM WRITE NOSYNC QD1 ###"
  sysbench fileio run --file-test-mode=rndwr --file-block-size=4096 --file-extra-flags=sync --file-fsync-freq=0 --file-fsync-end=on || fail

  if ! [[ "$OSTYPE" =~ ^darwin ]]; then
    echo "### RANDOM WRITE NOSYNC QD32 ###"
    sysbench fileio run --file-test-mode=rndwr --file-block-size=4096 --file-extra-flags=sync --file-fsync-freq=0 --file-fsync-end=on --file-io-mode=async --file-async-backlog=32 || fail
  fi

  # this should be final tests as they truncate files
  echo "### SEQUENTIAL WRITE FSYNC EVERY 100 REQ ###"
  sysbench fileio run --file-test-mode=seqwr --file-block-size=4096 --file-extra-flags=sync || fail

  echo "### SEQUENTIAL WRITE NOSYNC ###"
  sysbench fileio run --file-test-mode=seqwr --file-block-size=4096 --file-extra-flags=sync --file-fsync-freq=0 --file-fsync-end=on || fail

  sysbench fileio cleanup || fail
)
