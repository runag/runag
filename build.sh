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

set -o nounset

. bin/runag --skip-runagfile-load || { echo "Unable to load rùnag" >&2; exit 1; }

docs::make() {
  # rm docs/lib/*.md || softfail || return $?

  local files_list; files_list="$(mktemp)" || softfail || return $?
  local readme_content; readme_content="$(mktemp)" || softfail || return $?

  local file; for file in lib/*.sh; do
    if [ -f "${file}" ]; then
      local file_basename; file_basename="$(basename "${file}")" || softfail || return $?

      echo "* [${file_basename%%.*}](${file})" >> "${files_list}" || softfail || return $?

      # local output; output="docs/${file%.*}.md" || softfail || return $?
      # ?? <"${file}" >"${output}" || softfail || return $?
      # echo "* [${file_basename%%.*}](${output})" >> "${files_list}" || softfail || return $?
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

# run shellcheck
# shellcheck disable=SC2046
shellcheck build.sh index.sh \
  bin/* \
  $(find lib -name '*.sh') \
  $(find src -name '*.sh')

# make docs
docs::make || fail

# build files
bash src/deploy.sh
bash src/runag.sh
bash src/ssh-call.sh
bash src/deploy-offline.sh
