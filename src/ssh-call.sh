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

temp_file="$(mktemp)" || fail

{
  printf "#!/usr/bin/env bash\n\n" || fail

  runag::print_license || fail

  printf "\n"

  file::read_section set_shell_options bin/ssh-call || fail

  printf "\n"

  fail::function_sources || fail

  ssh::call::function_sources || fail

  declare -f log::notice || fail
  declare -f dir::ensure_exists || fail

  printf "\n"

  file::read_section run_ssh_call_command bin/ssh-call || fail

} >"${temp_file}" || fail

file::write --consume "${temp_file}" --mode 0755 dist/ssh-call || fail
