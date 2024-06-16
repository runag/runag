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

. bin/runag --skip-runagfile-load || { echo "Unable to load rùnag" >&2; exit 1; }

runag::online_deploy_script() {
  if [ "${RUNAG_VERBOSE:-}" = true ]; then
    PS4='+${BASH_SUBSHELL} ${BASH_SOURCE:+"${BASH_SOURCE}:${LINENO}: "}${FUNCNAME[0]:+"in \`${FUNCNAME[0]}'"'"' "}** '
    set -o xtrace
  fi
  set -o nounset

  git::install_git || softfail || return $?

  git::place_up_to_date_clone "${RUNAG_DIST_REPO}" "${HOME}/.runag" || softfail || return $?

  while [ "$#" -gt 0 ]; do
    case "$1" in
      add)
        runagfile::add "$2" || softfail || return $?
        shift; shift
        ;;
      run)
        shift
        "${HOME}/.runag/bin/runag" "$@" || softfail || return $?
        break
        ;;
      *)
        softfail "runag::online_deploy_script: command not found: $*" || return $?
        ;;
    esac
  done
}

runag_remote_url="$(git::get_remote_url_without_username)" || fail


temp_file="$(mktemp)" || fail

printf "#!/usr/bin/env bash\n\n" >"${temp_file}" || fail

runag::print_license >>"${temp_file}" || fail

echo '# This script is wrapped inside a function with a random name to lower the chance for the bash' >>"${temp_file}" || fail
echo '# to run some unexpected commands in case if "curl | bash" fails in the middle of download.' >>"${temp_file}" || fail
echo '__xVhMyefCbBnZFUQtwqCs() {' >>"${temp_file}" || fail

fail::function_sources >>"${temp_file}" || fail

declare -f apt::install >>"${temp_file}" || fail
declare -f apt::update >>"${temp_file}" || fail

declare -f git::install_git >>"${temp_file}" || fail
declare -f git::place_up_to_date_clone >>"${temp_file}" || fail
declare -f git::remove_current_clone >>"${temp_file}" || fail

declare -f runagfile::add >>"${temp_file}" || fail

declare -f runag::online_deploy_script >>"${temp_file}" || fail

# shellcheck disable=SC2016
echo 'export RUNAG_DIST_REPO="${RUNAG_DIST_REPO:-'"$(printf "%q" "${runag_remote_url}")"'}"' >>"${temp_file}" || fail

echo 'runag::online_deploy_script "$@"' >>"${temp_file}" || fail

echo '}; __xVhMyefCbBnZFUQtwqCs "$@"' >>"${temp_file}" || fail

file::write --absorb "${temp_file}" --mode 0644 deploy.sh || fail
