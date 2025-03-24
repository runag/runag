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

runag::offline_deploy_script() (
  if [ "${RUNAG_VERBOSE:-}" = true ]; then
    PS4='+${BASH_SUBSHELL} ${BASH_SOURCE:+"${BASH_SOURCE}:${LINENO}: "}${FUNCNAME[0]:+"in \`${FUNCNAME[0]}'"'"' "}** '
    set -o xtrace
  fi

  git::ensure_git_is_installed || fail

  local install_path="${HOME}/.runag"

  if [ ! -d runag.git ]; then
    fail "Unable to find runag.git directory"
  fi

  git::clone_or_update_local_mirror runag.git "${install_path}" "offline-install" || fail

  local runagfile_path; for runagfile_path in runagfiles/*; do
    if [ -d "${runagfile_path}" ]; then
      git::clone_or_update_local_mirror "${runagfile_path}" "${install_path}/${runagfile_path}" "offline-install" || fail
    fi
  done

  cd "${HOME}" || fail

  "${install_path}"/bin/runag
)

temp_file="$(mktemp)" || fail

{
  printf "#!/usr/bin/env bash\n\n" || fail

  runag::print_license || fail

  printf "set -o nounset\n\n" || fail

  fail::function_sources || fail

  declare -f apt::install || fail
  declare -f apt::update || fail

  declare -f git::ensure_git_is_installed || fail
  declare -f git::clone_or_update_local_mirror || fail

  declare -f runag::offline_deploy_script || fail

  echo 'runag::offline_deploy_script "$@"'

} >"${temp_file}" || fail

file::write --consume "${temp_file}" --mode 0644 deploy-offline.sh || fail
