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

$(declare -f terminal::color)
$(declare -f terminal::default-color)
$(declare -f log::notice)
$(declare -f log::error)
$(declare -f log::with-color)
$(declare -f fail)
$(declare -f softfail::internal)

# shellcheck disable=SC2030
$(declare -f task::run)
$(declare -f task::stderr-filter)
# shellcheck disable=SC2031
$(declare -f task::cleanup)

# shellcheck disable=SC2034
$(declare -f apt::update)
$(declare -f apt::install)

$(declare -f git::install-git)
$(declare -f git::place-up-to-date-clone)

$(declare -f sopka::add-sopkafile)

$(cat src/deploy-script.sh)

}; __xVhMyefCbBnZFUQtwqCs "\$@"
EOF
