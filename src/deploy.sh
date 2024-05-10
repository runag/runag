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

. bin/runag || { echo "Unable to load rùnag" >&2; exit 1; }

runag::online_deploy_script() {
  if [ "${RUNAG_VERBOSE:-}" = true ]; then
    set -o xtrace
  fi
  set -o nounset

  git::install_git || softfail || return $?

  git::place_up_to_date_clone "${RUNAG_DIST_REPO}" "${HOME}/.runag" || softfail || return $?

  while [ "$#" -gt 0 ]; do
    case $1 in
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

file::write deploy.sh <<SHELL || fail
#!/usr/bin/env bash

$(runag::print_license)

# This script is wrapped inside a function with a random name to lower the chance for the bash
# to run some unexpected commands in case if "curl | bash" fails in the middle of download.
__xVhMyefCbBnZFUQtwqCs() {

$(fail::function_sources)

$(declare -f apt::install)
$(declare -f apt::update)

$(declare -f git::install_git)
$(declare -f git::place_up_to_date_clone)
$(declare -f git::remove_current_clone)

$(declare -f runagfile::add)

$(declare -f runag::online_deploy_script)

export RUNAG_DIST_REPO="\${RUNAG_DIST_REPO:-$(printf "%q" "${runag_remote_url}")}"

runag::online_deploy_script "\$@"

}; __xVhMyefCbBnZFUQtwqCs "\$@"
SHELL
