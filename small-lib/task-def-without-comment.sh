#!/usr/bin/env bash

#  Copyright 2012-2025 Runag project contributors
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

# Helper function to define and format a task for output
# Usage: task::def <task command...>
# * Formats the task in a readable or fzf-compatible form
task::def() {
  # Quote each part of the task command safely for reuse or display
  local quoted_cmd
  printf -v quoted_cmd " %q" "$@" &&

  # Format differently depending on output mode (fzf vs plain)
  if [ "${TASK_MODE:-}" = fzf ]; then
    printf '%s\n%s\0' "${quoted_cmd:1}" "$*"  # NUL-delimited for fzf preview
  else
    printf '  %s\n' "${quoted_cmd:1}"  # Indented plain text output
  fi
}
