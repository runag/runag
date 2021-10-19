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

file::write deploy.sh <<EOF || fail
#!/usr/bin/env bash

$(sopka::print-license)

# Script is wrapped inside a function with a random name to lower the chance
# of "curl | bash" to run some unexpected command in case if script download fails in the middle.

__xVhMyefCbBnZFUQtwqCs() {

$(declare -f apt::install)
$(declare -f apt::update)
$(declare -f deploy-script::add)
$(declare -f deploy-script::run)
$(declare -f deploy-script)
$(declare -f fail)
$(declare -f git::install-git)
$(declare -f git::place-up-to-date-clone)
$(declare -f log::error-trace)
$(declare -f log::error)
$(declare -f log::notice)
$(declare -f log::with-color)
$(declare -f softfail-unless-good-code)
$(declare -f softfail-unless-good::internal)
$(declare -f softfail::internal)
$(declare -f softfail)
$(declare -f sopka::add-sopkafile)
$(declare -f task::cleanup)
$(declare -f task::detect-fail-state)
$(declare -f task::is-stderr-empty-after-filtering)
$(declare -f task::run)
$(declare -f task::stderr-filter)
$(declare -f terminal::color)
$(declare -f terminal::default-color)

if [ "\${SOPKA_VERBOSE:-}" = true ]; then
  set -o xtrace
fi
set -o nounset

task::run git::install-git || softfail || return $?

task::run git::place-up-to-date-clone "https://github.com/senotrusov/sopka.git" "\${HOME}/.sopka" || softfail || return $?

deploy-script "\$@"
softfail-unless-good-code \$?

}; __xVhMyefCbBnZFUQtwqCs "\$@"
EOF
