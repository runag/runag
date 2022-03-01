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

sopka::deploy_sh_main() {
  if [ "${SOPKA_VERBOSE:-}" = true ]; then
    set -o xtrace
  fi
  set -o nounset

  task::run_with_install_filter git::install_git || softfail || return $?

  task::run_with_install_filter git::place_up_to_date_clone "https://github.com/senotrusov/sopka.git" "${HOME}/.sopka" || softfail || return $?

  deploy_script "$@"
  softfail_unless_good_code $?
}

file::write deploy.sh <<SHELL || fail
#!/usr/bin/env bash

$(sopka::print_license)

# Script is wrapped inside a function with a random name to lower the chance
# of "curl | bash" to run some unexpected command in case if script download fails in the middle.

__xVhMyefCbBnZFUQtwqCs() {

$(declare -f apt::install)
$(declare -f apt::update)
$(declare -f deploy_script::add)
$(declare -f deploy_script::run)
$(declare -f deploy_script)
$(declare -f fail)
$(declare -f git::install_git)
$(declare -f git::place_up_to_date_clone)
$(declare -f log::error_trace)
$(declare -f log::error)
$(declare -f log::notice)
$(declare -f log::with_color)
$(declare -f softfail_unless_good_code)
$(declare -f softfail_unless_good::internal)
$(declare -f softfail::internal)
$(declare -f softfail)
$(declare -f sopka::add_sopkafile)
$(declare -f sopka::deploy_sh_main)
$(declare -f task::complete_with_cleanup)
$(declare -f task::complete)
$(declare -f task::detect_fail_state)
$(declare -f task::install_filter)
$(declare -f task::is_stderr_empty_after_filtering)
$(declare -f task::run_with_install_filter)
$(declare -f task::run)
$(declare -f terminal::color)
$(declare -f terminal::default_color)

sopka::deploy_sh_main "\$@"

}; __xVhMyefCbBnZFUQtwqCs "\$@"
SHELL
