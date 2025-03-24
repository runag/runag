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

runag::online_deploy_script() {
  if [ "${RUNAG_VERBOSE:-}" = true ]; then
    PS4='+${BASH_SUBSHELL} ${BASH_SOURCE:+"${BASH_SOURCE}:${LINENO}: "}${FUNCNAME[0]:+"in \`${FUNCNAME[0]}'"'"' "}** '
    set -o xtrace
  fi

  git::ensure_git_is_installed || softfail || return $?

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

{
  printf "#!/usr/bin/env bash\n\n" || fail

  runag::print_license || fail

  printf "set -o nounset\n\n" || fail

  echo '# This script is wrapped inside a function with a random name to lower the chance for the bash'
  echo '# to run some unexpected commands in case if "curl | bash" fails in the middle of download.'
  echo '__xVhMyefCbBnZFUQtwqCs() {'

  fail::function_sources || fail

  declare -f apt::install || fail
  declare -f apt::update || fail

  declare -f git::ensure_git_is_installed || fail
  declare -f git::place_up_to_date_clone || fail
  declare -f git::remove_current_clone || fail

  declare -f runagfile::add || fail
  declare -f runag::online_deploy_script || fail

  # shellcheck disable=SC2016
  printf 'export RUNAG_DIST_REPO="${RUNAG_DIST_REPO:-%q}"\n' "${runag_remote_url}"

  echo 'runag::online_deploy_script "$@"'

  echo '}; __xVhMyefCbBnZFUQtwqCs "$@"'

} >"${temp_file}" || fail

file::write --consume "${temp_file}" --mode 0644 deploy.sh || fail
