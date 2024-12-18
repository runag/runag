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

# ### `task::any`
#
# Checks whether the global task array `RUNAG_TASK` exists and contains at least one entry.
#
task::any() {
  # Verify that the RUNAG_TASK array is defined and contains at least one element.
  # -v ensures RUNAG_TASK is a defined variable.
  # ${#RUNAG_TASK[@]} retrieves the number of elements in the array.
  [[ -v RUNAG_TASK ]] && (( ${#RUNAG_TASK[@]} > 0 ))
}

# ### `task::clear`
#
# Clears the global task array `RUNAG_TASK` by resetting it to an empty state.
#
task::clear() {
  # Declare RUNAG_TASK as a global (-g) empty array (-a).
  declare -ga RUNAG_TASK=()
}

# ### `task::add`
#
# Adds a task to the global task array `RUNAG_TASK`. 
# By default, tasks are categorized as "basic-task". If specified, they can be categorized as a "task-group".
#
# #### Parameters:
#
#   - `-g` or `--group` : Marks the task as a "task-group" type.
#   - Remaining arguments are treated as task details.
#
task::add() {
  local task_type="basic-task"  # Default task type.

  # Parse optional flags before processing arguments.
  while [ "$#" -gt 0 ]; do
    case "$1" in
      -g|--group)
        task_type="task-group"  # Set task type to "task-group".
        shift
        ;;
      *)
        break  # Stop flag parsing when encountering a non-flag argument.
        ;;
    esac
  done

  # Ensure the global RUNAG_TASK array is initialized before adding tasks.
  if [[ ! -v RUNAG_TASK ]]; then
    declare -ga RUNAG_TASK=()
  fi

  # Append a task to the RUNAG_TASK array.
  # Each task entry includes: task type, argument count, and the task arguments.
  RUNAG_TASK+=("${task_type}" "$#" "$@")
}

# ### `task::group`
# 
# Runs a task group function that populates the `RUNAG_TASK` array.
# This function clears any existing tasks, runs the provided group function to populate tasks,
# and displays the updated task list.
#
task::group() (
  local nested_display

  # Parse function arguments
  while [ "$#" -gt 0 ]; do
    case "$1" in
      -n|--nested-display)
        nested_display=true
        shift
        ;;
      -*)
        softfail "Unrecognized argument: $1" || return $?
        ;;
      *)
        break
        ;;
    esac
  done

  # Clear any existing tasks in the `RUNAG_TASK` array to start fresh.
  task::clear || softfail || return $?

  # Run the specified task group function, which should define the tasks to be managed.
  runag::command "$@"
  softfail --unless-good --exit-status $? "Error ($?) occurred while processing the task group function: $*" || return $?

  # Display the current task list with nested display mode.
  task::display ${nested_display:+"--nested-display"}

  local task_exit_status=$?

  # If the `task::display` function returns a status code of 130, propagate this status code upstream.
  if [ "${task_exit_status}" = 130 ] && [ "${nested_display:-}" = true ]; then
    return "${task_exit_status}"
  fi

  # Handle errors from `task::display` and log an appropriate message.
  softfail --unless-good --exit-status "${task_exit_status}" "Error: task::display encountered an issue (${task_exit_status})" || return $?
)

# ### `task::display`
# 
# #### Description:
# Displays tasks interactively or non-interactively based on the availability of `fzf`.
# Allows the selection of tasks or task groups for processing. If `fzf` is not available
# or input/output is not a terminal, it falls back to rendering tasks non-interactively.
#
# #### Parameters:
# - `-n`, `--nested-display`: Specifies that the function is running in a nested context.
#                             Used to determine behavior when `fzf` selection is canceled.

task::display() {
  # Validate if any tasks are present
  task::any || softfail "The task list is empty" || return $?

  local nested_display

  # Parse function arguments
  while [ "$#" -gt 0 ]; do
    case "$1" in
      -n|--nested-display)
        nested_display=true
        shift
        ;;
      -*)
        softfail "Unrecognized argument: $1" || return $?
        ;;
      *)
        break
        ;;
    esac
  done

  # Check if `fzf` is available and if stdin (0) and stdout (1) are terminals
  if ! [ -t 0 ] || ! [ -t 1 ] || ! command -v fzf >/dev/null; then
    task::render --non-interactive || softfail || return $?
    return $?
  fi

  # Set up color attributes if output is a terminal or color output is forced
  local prompt_color=""
  local reset_attrs=""

  # check if stdout (1) is a terminal
  if [ -t 1 ]; then
    prompt_color="$(printf "setaf 11\nbold" | tput -S 2>/dev/null)" || prompt_color=""
    reset_attrs="$(tput sgr 0 2>/dev/null)" || reset_attrs=""
  fi


  # Begin interactive task selection loop
  while : ; do
    local fzf_result_string
    local main_pointer
    local line_number

    # The `read` command combined with the `lastpipe` shell option cannot be used here because it's uncertain whether job control is enabled.

    # Render tasks and use `fzf` for selection
    fzf_result_string="$(
      ( task::render --force-color-output || softfail "Error in task::render ($?)" || exit 2 ) |
      fzf --ansi --tac --with-nth="3.." ${line_number:+--bind "load:pos:-${line_number}"} |
      ( cut -d " " -f 1-2 || softfail "Error in cut ($?)" || exit 2 )
      
      # Check pipeline statuses
      for status in "${PIPESTATUS[@]}"; do
        if [ "${status}" -ne 0 ]; then
          exit "${status}"
        fi
      done

      exit 0
    )"

    # Capture the status of `fzf`
    local fzf_status=$?

    if [ "${fzf_status}" = 1 ] || [ "${fzf_status}" = 130 ]; then
      if [ "${nested_display:-}" = true ]; then
        return 130
      fi
      return 0
    fi

    softfail --unless-good --exit-status "${fzf_status}" "Task selection error" || return $?

    <<<"${fzf_result_string}" IFS=" " read -r main_pointer line_number

    [[ "${main_pointer}" =~ ^[0-9]+$ ]] || softfail "Invalid task pointer: Non-numeric value" || return $?
    [[ "${line_number}" =~ ^[0-9]+$ ]] || softfail "Invalid line_number: Non-numeric value" || return $?

    # Retrieve task information
    local item_type="${RUNAG_TASK[main_pointer]}"
    local item_length="${RUNAG_TASK[main_pointer + 1]}"

    [[ "${item_length}" =~ ^[0-9]+$ ]] || softfail "Invalid task length: Non-numeric value" || return $?

    if [ "${item_type}" != "basic-task" ] && [ "${item_type}" != "task-group" ]; then
      softfail "Unrecognized item type: ${item_type}" || return $?
    fi

    local command_array=()

    # Determine if the item is a task group or basic task
    if [ "${item_type}" = "task-group" ]; then
      command_array+=(task::group --nested-display)
    else
      command_array+=(runag::command)
    fi

    local item_pointer

    # Parse additional arguments for the selected task
    for (( item_pointer = main_pointer + 2; item_pointer <= main_pointer + item_length + 1; item_pointer++ )); do 
      case "${RUNAG_TASK[item_pointer]}" in
        -c|--comment)
          (( item_pointer += 1 )) # Skip comment value
          ;;
        -*)
          softfail "Unrecognized argument: ${RUNAG_TASK[item_pointer]}" || return $?
          ;;
        *)
          break
          ;;
      esac
    done

    # Validate that a command is present
    if ! (( item_pointer <= main_pointer + item_length + 1 )); then
      softfail "Task contains no actionable command" || return $?
    fi

    command_array+=("${RUNAG_TASK[@]:item_pointer:((item_length - (item_pointer - main_pointer - 2)))}")

    if [ -t 1 ] && [ "${item_type}" != "task-group" ]; then
      echo $'\n'"${prompt_color}> ${command_array[*]}${reset_attrs}" 
    fi

    "${command_array[@]}"

    local command_status=$?

    # If the command is part of a task group, continue iteration on cancellation
    if [ "${command_status}" = 130 ] && [ "${item_type}" = "task-group" ]; then
      continue
    fi

    softfail --unless-good --exit-status "${command_status}" "Error (${command_status}) performing command: ${command_array[*]}" || return $?

    return "${command_status}"
  done
}

# ### `task::render`
# 
# #### Description:
# Renders tasks to the output, either interactively with colors or non-interactively
# if specified. Ensures consistent formatting of tasks and their metadata.
#
# #### Parameters:
# - `-n`, `--non-interactive`: Disables colorized output and renders tasks in plain text.
# - `-c`, `--force-color-output`: Forces colorized output, regardless of terminal detection.

task::render() {
  local non_interactive=false
  local force_color_output=false

  # Parse function arguments
  while [ "$#" -gt 0 ]; do
    case "$1" in
      -n|--non-interactive)
        non_interactive=true
        shift
        ;;
      -c|--force-color-output)
        force_color_output=true
        shift
        ;;
      *)
        softfail "Unrecognized argument: $1" || return $?
        ;;
    esac
  done

  # Color palette:
  #   1 - color a
  #   3 - prompt
  #   5 - header
  #   6 - comment
  #
  # color_a="$(tput setaf 9 2>/dev/null)" || color_a=""
  # color_a_accent="$(printf "setaf 15\nsetab 9" | tput -S 2>/dev/null)" || color_a_accent=""
  # color_b_accent="$(printf "setaf 15\nsetab 8" | tput -S 2>/dev/null)" || color_b_accent=""
  # header_color="$(printf "setaf 14\nbold" | tput -S 2>/dev/null)" || header_color=""

  # Standard streams:
  #   0 - stdin
  #   1 - stdout
  #   2 - stderr

  # Set up color attributes if output is a terminal or color output is forced
  local comment_color=""
  local reset_attrs=""

  # check if stdout (1) is a terminal
  if [ -t 1 ] || [ "${force_color_output}" = true ]; then
    comment_color="$(printf "setaf 13\nbold" | tput -S 2>/dev/null)" || comment_color=""
    reset_attrs="$(tput sgr 0 2>/dev/null)" || reset_attrs=""
  fi

  # State machine example:
  #
  #            |             |     |     |     |            |
  # 0          | 1           | 2   | 3   | 4   | 5          | 6
  # 4          | 5           | 6   | 7   | 8   | 9          | 10
  # op         | item_length |     |     |     | op         | item_length
  # basic-task | 3           | foo | bar | qux | basic-task |
  #
  # main_pointer 4
  # item_pointer 7
  # item_length  3

  # Iterate through tasks and format their output
  local main_pointer
  local output_line_number=1

  for (( main_pointer = 0; main_pointer < ${#RUNAG_TASK[@]}; main_pointer++ )); do 
    local item_type="${RUNAG_TASK[main_pointer]}"
    local item_length="${RUNAG_TASK[main_pointer + 1]}"

    [[ "${item_length}" =~ ^[0-9]+$ ]] || softfail "Invalid task length: Non-numeric value" || return $?

    if [ "${item_type}" != "basic-task" ] && [ "${item_type}" != "task-group" ]; then
      softfail "Unrecognized item type: ${item_type}" || return $?
    fi

    local command_array=()
    local comment=""

    # Add task group-specific formatting
    if [ "${item_type}" = "task-group" ]; then
      comment="-->"
      command_array+=(task::group)
    fi

    local item_pointer

    # Parse task arguments
    for (( item_pointer = main_pointer + 2; item_pointer <= main_pointer + item_length + 1; item_pointer++ )); do 
      case "${RUNAG_TASK[item_pointer]}" in
        -c|--comment)
          (( item_pointer += 1 )) # Capture comment value
          comment="${RUNAG_TASK[item_pointer]}"
          ;;
        -*)
          softfail "Unrecognized argument: ${RUNAG_TASK[item_pointer]}" || return $?
          ;;
        *)
          break
          ;;
      esac
    done

    (( item_pointer <= main_pointer + item_length + 1 )) || softfail "Task contains no actionable command" || return $?

    local command_pointer=""

    if [ "${non_interactive}" = false ]; then
      command_pointer="${main_pointer} ${output_line_number}"
    fi

    command_array+=("${RUNAG_TASK[@]:item_pointer:((item_length - (item_pointer - main_pointer - 2)))}")

    echo "${command_pointer:+"${command_pointer} "}${command_array[*]}${comment:+" ${comment_color}# ${comment}${reset_attrs}"}"

    (( output_line_number += 1 ))
    (( main_pointer += item_length + 1 ))
  done
}
