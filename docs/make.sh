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

. bin/sopka || { echo "Unable to load sopka" >&2; exit 1; }

shdoc::install() {
  local tempDir; tempDir="$(mktemp -d)" || fail
  git clone --recursive https://github.com/reconquest/shdoc "${tempDir}" || fail
  (cd "${tempDir}" && make && sudo make install) || fail
  rm -rf "${tempDir}" || fail
}

if ! command -v gawk >/dev/null; then
  sudo apt install gawk || fail
fi

if ! command -v shdoc >/dev/null; then
  shdoc::install || fail
fi

rm docs/lib/*.md || fail

for file in lib/*.sh; do
  if [ -f "${file}" ]; then
    output="docs/${file%.*}.md"
    file_basename="$(basename "${file}")" || fail

    shdoc <"${file}" > "${output}" || fail
    echo "* [${file_basename%%.*}](${output})"
  fi
done
