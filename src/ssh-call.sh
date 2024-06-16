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

temp_file="$(mktemp)" || fail

printf "#!/usr/bin/env bash\n\n" >"${temp_file}" || fail

runag::print_license >>"${temp_file}" || fail

file::get_block bin/ssh-call set_shell_options >>"${temp_file}" || fail

fail::function_sources >>"${temp_file}" || fail

ssh::call::function_sources >>"${temp_file}" || fail

declare -f log::notice >>"${temp_file}" || fail
declare -f dir::should_exists >>"${temp_file}" || fail

file::get_block bin/ssh-call run_ssh_call_command >>"${temp_file}" || fail

file::write --absorb "${temp_file}" --mode 0755 dist/ssh-call || fail
