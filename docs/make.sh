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

. bin/runag || { echo "Unable to load rùnag" >&2; exit 1; }

shdoc::install() {
  local temp_dir; temp_dir="$(mktemp -d)" || softfail || return $?
  git clone --recursive https://github.com/reconquest/shdoc "${temp_dir}" || softfail || return $?
  (cd "${temp_dir}" && make && sudo make install) || softfail || return $?
  rm -rf "${temp_dir}" || softfail || return $?
}

docs::make() {
  rm docs/lib/*.md || softfail || return $?

  local files_list; files_list="$(mktemp)" || softfail || return $?
  local readme_content; readme_content="$(mktemp)" || softfail || return $?

  local file; for file in lib/*.sh; do
    if [ -f "${file}" ]; then
      local output; output="docs/${file%.*}.md" || softfail || return $?
      local file_basename; file_basename="$(basename "${file}")" || softfail || return $?

      shdoc <"${file}" >"${output}" || softfail || return $?
      # TODO: I hope that happy moment to enable this line will come
      # echo "* [${file_basename%%.*}](${output})" >> "${files_list}" || softfail || return $?
      echo "* [${file_basename%%.*}](${file})" >> "${files_list}" || softfail || return $?
    fi
  done

  sort "${files_list}" > "${files_list}.tmp" || softfail || return $?
  mv "${files_list}.tmp" "${files_list}" || softfail || return $?
  
  # "awk NF" is to remove empty line
  < README.md awk '/API TOC BEGIN/{ line = 1; next } /API TOC END/{ line = 0 } line' | grep -v "^###" | awk NF | sort > "${readme_content}"
  test "${PIPESTATUS[*]}" = "0 0 0 0" || softfail || return $?

  if ! diff --strip-trailing-cr "${readme_content}" "${files_list}" >/dev/null 2>&1; then
    if command -v git >/dev/null; then
      git diff --ignore-cr-at-eol --color --unified=6 --no-index "${readme_content}" "${files_list}" | tee
    else
      diff --strip-trailing-cr --context=6 --color "${readme_content}" "${files_list}"
    fi
    log::error "Please update API TOC in README.md"
  fi

  rm "${files_list}" || softfail || return $?
  rm "${readme_content}" || softfail || return $?
}

if ! command -v gawk >/dev/null; then
  sudo apt install gawk || fail
fi

if ! command -v shdoc >/dev/null; then
  shdoc::install || fail
fi

docs::make || fail
