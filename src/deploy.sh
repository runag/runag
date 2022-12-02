#!/usr/bin/env bash

#  Copyright 2012-2022 Stanislav Senotrusov <stan@senotrusov.com>
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

runag::deploy_sh_main() {
  if [ "${RUNAG_VERBOSE:-}" = true ]; then
    set -o xtrace
  fi
  set -o nounset

  task::run_with_install_filter git::install_git || softfail || return $?

  task::run_with_install_filter git::place_up_to_date_clone "${RUNAG_DIST_REPO}" "${HOME}/.sopka" || softfail || return $?

  deploy_script "$@"
  softfail_unless_good_code $?
}

sopka_remote_url="$(git::get_remote_url_without_username)" || fail

file::write deploy.sh <<SHELL || fail
#!/usr/bin/env bash

$(runag::print_license)

# Script is wrapped inside a function with a random name to lower the chance
# of "curl | bash" to run some unexpected command in case if script download fails in the middle.

__xVhMyefCbBnZFUQtwqCs() {

$(deploy_script::function_sources)
$(fail::function_sources)
$(log::function_sources)
$(task::function_sources)
$(terminal::function_sources)

$(declare -f apt::install)
$(declare -f apt::update)

$(declare -f git::install_git)
$(declare -f git::place_up_to_date_clone)

$(declare -f runagfile::add)

$(declare -f runag::deploy_sh_main)

export RUNAG_DIST_REPO="\${RUNAG_DIST_REPO:-$(printf "%q" "${sopka_remote_url}")}"

runag::deploy_sh_main "\$@"

}; __xVhMyefCbBnZFUQtwqCs "\$@"
SHELL
