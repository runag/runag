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
# Usage: task::def [-c|--comment <comment>] <task command...>
# * Formats the task in a readable or fzf-compatible form
# * Optionally appends a comment to the task line (with optional styling for fzf)
task::def() {
  local comment quoted_cmd

  # Parse optional flags before the task command
  while [[ "$1" == -* ]]; do
    case "$1" in
      -c|--comment) comment=" # $2"; shift 2 ;;  # Store comment with leading marker
      *) echo "Unknown argument: $1" >&2; return 1 ;;
    esac
  done

  # Quote each part of the task command safely for reuse or display
  printf -v quoted_cmd " %q" "$@" &&

  # Format differently depending on output mode (fzf vs plain)
  if [ "${TASK_MODE:-}" = fzf ]; then
    # Apply styling to the comment if defined
    [ -n "$comment" ] && comment="$(printf "setaf 13\nbold" | tput -S 2>/dev/null)${comment}$(tput sgr0 2>/dev/null)"
    printf '%s\n%s%s\0' "${quoted_cmd:1}" "$*" "$comment"  # NUL-delimited for fzf preview
  else
    printf '  %s%s\n' "${quoted_cmd:1}" "$comment"  # Indented plain text output
  fi
}

# Display a list of tasks and optionally allow interactive selection
# Usage: task::pick <task-generator-function> [args...]
# * If `fzf` is available, uses it to select a task interactively
# * Otherwise, prints the list of tasks to stdout
task::pick() {
  local TASK_MODE chosen_task

  # Determine if terminal supports interaction and if `fzf` is installed
  if [ -t 0 ] && [ -t 1 ] && command -v fzf >/dev/null; then
    TASK_MODE=fzf

    # Generate task list and use fzf to select a task interactively
    chosen_task="$("$@" | fzf --with-nth=2.. --accept-nth=1 --delimiter='\n' --read0 --ansi --cycle --wrap; \
      [[ "${PIPESTATUS[*]}" =~ ^0\ (0|1|130)$ ]])" || {
        echo "Task selection failed: task generator or fzf encountered an issue." >&2
        return 1
      }

    eval "$chosen_task"  # Run the selected task
  else
    echo "Available tasks:"
    "$@"  # Print tasks to stdout if not interactive
  fi
}
