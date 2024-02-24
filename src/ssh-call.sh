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

file::write --mode 0755 bin/ssh-call <<SHELL || fail
#!/usr/bin/env bash

$(runag::print_license)

# set shell options if we are not sourced
if [ "\${BASH_SOURCE[0]}" = "\$0" ]; then
  if [ "\${RUNAG_VERBOSE:-}" = true ]; then
    set -o xtrace
  fi
  set -o nounset
fi

$(fail::function_sources)
$(ssh::call::function_sources)

$(declare -f log::notice)
$(declare -f dir::should_exists)

# run command if we are not sourced
if [ "\${BASH_SOURCE[0]}" = "\$0" ]; then
  ssh::call --command "\$@"
  softfail --unless-good --exit-status \$? || exit \$?
fi
SHELL
