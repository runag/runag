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
  # Verifies that the RUNAG_TASK array is defined and contains at least one element.
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
  # `declare -g` requires Bash 4.2 or newer (released in 2011)
  declare -ga RUNAG_TASK=() || softfail "Failed to clear the task array: unable to reset RUNAG_TASK." || return $?
}

# ### `task::add`
#
# Adds a task to the global task array `RUNAG_TASK`.
# By default, tasks are categorized as "basic-task". If specified, they can be categorized as a "task-group".
#
# #### Parameters:
#
#   - `-g` or `--group`: Marks the task as a "task-group" type.
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
        break  # Stop flag parsing.
        ;;
    esac
  done

  # Ensure the global RUNAG_TASK array is initialized before adding tasks.
  if [[ ! -v RUNAG_TASK ]]; then
    # `declare -g` requires Bash 4.2 or newer (released in 2011)
    declare -ga RUNAG_TASK=()
  fi

  # Append a task to the RUNAG_TASK array.
  # Each task entry includes: task type, argument count, and the task arguments.
  RUNAG_TASK+=("${task_type}" "$#" "$@")

  if [ "${task_type}" = "task-group" ]; then
    # Assign the task group function name from the first argument.
    local function_name="$1"

    # Verify if the specified task group function is already defined.
    # If the function ${function_name} is not declared but its corresponding task set creation function
    # ${function_name}::set is defined, dynamically create the task group function.
    if ! declare -F "${function_name}" >/dev/null && declare -F "${function_name}::set" >/dev/null; then
      # Ensure the function name contains only valid characters.
      [[ "${function_name}" =~ ^[a-zA-Z0-9:_]+$ ]] || softfail "Error: Function name must contain only alphanumeric characters, colons (:), and underscores (_)." || return $?

      # Create a function that calls `task::display` with arguments.
      eval "${function_name}() { task::display "\$@" ${function_name}::set; }"
    fi
  fi
}

# ### `task::display`
#
# Interactively or non-interactively displays tasks, depending on the availability of `fzf`.
# This function allows the user to select tasks or task groups for processing. If `fzf` is not
# available or the input/output is not a terminal, it will fallback to non-interactive task rendering.
#
# #### Parameters:
#
# - `-n`, `--nested-display`: Indicates that the function is running in a nested context.
#                             This affects the behavior when the task selection via `fzf` is canceled.
#
task::display() {
  # Check if any tasks exist.
  task::any || softfail "The task list is empty." || return $?

  local nested_display

  # Parse function arguments.
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

  # If additional arguments are provided, invoke the task group function and display tasks.
  if [[ $# -gt 0 ]]; then
    ( 
    # Clear any existing tasks in the `RUNAG_TASK` array.
    task::clear || softfail "Error clearing tasks." || return $?

    # Invoke the task group function to define the tasks to be managed.
    runag::invoke --no-subshell "$@"
    softfail --unless-good --status $? "Error occurred while processing the task group function ($?): $*" || return $?

    # Display the task list with optional nested display mode.
    task::display ${nested_display:+"--nested-display"}
    )

    return $?
  fi

  # Check if `fzf` is available and if both stdin (0) and stdout (1) are terminals.
  if ! [ -t 0 ] || ! [ -t 1 ] || ! command -v fzf >/dev/null; then
    task::render --non-interactive || softfail "Error rendering tasks non-interactively." || return $?
    return $?
  fi

  # Set color attributes for terminal output if necessary.
  local prompt_color=""
  local reset_attrs=""

  # If stdout (1) is a terminal, set color attributes.
  if [ -t 1 ]; then
    prompt_color="$(printf "setaf 11\nbold" | tput -S 2>/dev/null)" || prompt_color=""
    reset_attrs="$(tput sgr 0 2>/dev/null)" || reset_attrs=""
  fi

  # Begin the interactive task selection loop.
  while : ; do
    local fzf_result_string
    local main_pointer
    local line_number

    # The `read` command combined with the `lastpipe` shell option cannot be used here 
    # because it's uncertain whether job control is enabled.

    # Render tasks and use `fzf` for interactive selection.
    fzf_result_string="$(
      ( task::render --force-color-output || softfail "Error in task::render ($?)" || exit 2 ) |
      fzf --ansi --cycle --tac --with-nth="3.." --wrap ${line_number:+--bind "load:pos:-${line_number}"} |
      ( cut -d " " -f 1-2 || softfail "Error in cut ($?)" || exit 2 )
      
      # Check pipeline statuses for errors.
      for status in "${PIPESTATUS[@]}"; do
        if [ "${status}" -ne 0 ]; then
          exit "${status}"
        fi
      done

      exit 0
    )"

    # Capture the status of `fzf`.
    local fzf_status=$?

    # Handle the case where task selection was canceled.
    if [ "${fzf_status}" = 1 ] || [ "${fzf_status}" = 130 ]; then
      if [ "${nested_display:-}" = true ]; then
        return 130  # Return with code 130 if in nested display mode.
      fi
      return 0  # Return 0 to indicate normal exit.
    fi

    # Handle errors during task selection.
    softfail --unless-good --status "${fzf_status}" "Error during task selection." || return $?

    # Parse the result from `fzf` to obtain the selected task.
    <<<"${fzf_result_string}" IFS=" " read -r main_pointer line_number

    # Validate the format of the task pointer and line number.
    [[ "${main_pointer}" =~ ^[0-9]+$ ]] || softfail "Invalid task pointer: Non-numeric value." || return $?
    [[ "${line_number}" =~ ^[0-9]+$ ]] || softfail "Invalid line_number: Non-numeric value." || return $?

    # Retrieve task information.
    local item_type="${RUNAG_TASK[main_pointer]}"
    local item_length="${RUNAG_TASK[main_pointer + 1]}"

    # Ensure the task length is a valid numeric value.
    [[ "${item_length}" =~ ^[0-9]+$ ]] || softfail "Invalid task length: Non-numeric value." || return $?

    # Verify that the task type is recognized.
    if [ "${item_type}" != "basic-task" ] && [ "${item_type}" != "task-group" ]; then
      softfail "Unrecognized item type: ${item_type}" || return $?
    fi

    # Initialize the command array for the task.
    local command_array=(runag::invoke)

    local item_pointer

    # Parse additional arguments for the selected task.
    for (( item_pointer = main_pointer + 2; item_pointer <= main_pointer + item_length + 1; item_pointer++ )); do 
      case "${RUNAG_TASK[item_pointer]}" in
        -c|--comment)
          (( item_pointer += 1 )) # Skip comment value.
          ;;
        -*)
          softfail "Unrecognized argument: ${RUNAG_TASK[item_pointer]}" || return $?
          ;;
        *)
          break
          ;;
      esac
    done

    # Ensure the task contains a valid command.
    if ! (( item_pointer <= main_pointer + item_length + 1 )); then
      softfail "Task contains no executable command." || return $?
    fi

    # Add the remaining arguments for the selected task to the command array.
    command_array+=("${RUNAG_TASK[@]:item_pointer:((item_length - (item_pointer - main_pointer - 2)))}")

    # If output is a terminal, print the command before execution.
    if [ -t 1 ] && [ "${item_type}" != "task-group" ]; then
      echo $'\n'"${prompt_color}> ${command_array[*]}${reset_attrs}" 
    fi

    # If the task is a task group, pass the nested display option.
    if [ "${item_type}" = "task-group" ]; then
      command_array+=(--nested-display)
    fi

    # Run the task command.
    "${command_array[@]}"

    local command_status=$?

    # If the task is part of a task group, continue iteration on cancellation.
    if [ "${command_status}" = 130 ] && [ "${item_type}" = "task-group" ]; then
      continue
    fi

    # Handle errors during task execution.
    softfail --unless-good --status "${command_status}" "Error performing command (${command_status}): ${command_array[*]}" || return $?

    return "${command_status}"
  done
}

# ### `task::render`
#
# Renders tasks to the output, either interactively with colors or non-interactively
# if specified. Ensures consistent formatting of tasks and their metadata.
#
# #### Parameters:
#
# - `-n`, `--non-interactive`: Disables colorized output and renders tasks in plain text.
# - `-c`, `--force-color-output`: Forces colorized output, regardless of terminal detection.
#
task::render() {
  local non_interactive=false
  local force_color_output=false

  # Parse function arguments.
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

  # Define color attributes for output, setting them only if necessary.
  local comment_color=""
  local end_marker_color=""
  local reset_attrs=""

  # Check if stdout is a terminal or if color output is forced.
  if [ -t 1 ] || [ "${force_color_output}" = true ]; then
    comment_color="$(printf "setaf 13\nbold" | tput -S 2>/dev/null)" || comment_color=""
    end_marker_color="$(printf "setaf 14\nbold" | tput -S 2>/dev/null)" || end_marker_color=""
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

  # Iterate through tasks stored in the RUNAG_TASK array and format their output.
  local main_pointer
  local output_line_number=1

  for (( main_pointer = 0; main_pointer < ${#RUNAG_TASK[@]}; main_pointer++ )); do 
    local item_type="${RUNAG_TASK[main_pointer]}"
    local item_length="${RUNAG_TASK[main_pointer + 1]}"

    # Validate item length is a numeric value.
    [[ "${item_length}" =~ ^[0-9]+$ ]] || softfail "Invalid task length: Non-numeric value" || return $?

    # Validate item type is recognized.
    if [ "${item_type}" != "basic-task" ] && [ "${item_type}" != "task-group" ]; then
      softfail "Unrecognized item type: ${item_type}" || return $?
    fi

    local command_array=()
    local comment=""
    local end_marker=""

    # Add task group-specific formatting if applicable.
    if [ "${item_type}" = "task-group" ]; then
      end_marker="-->"
    fi

    local item_pointer

    # Parse task arguments.
    for (( item_pointer = main_pointer + 2; item_pointer <= main_pointer + item_length + 1; item_pointer++ )); do 
      case "${RUNAG_TASK[item_pointer]}" in
        -c|--comment)
          (( item_pointer += 1 )) # Capture comment value.
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

    # Ensure task has actionable commands.
    (( item_pointer <= main_pointer + item_length + 1 )) || softfail "Task contains no actionable command" || return $?

    local command_pointer=""

    # Prepare interactive output if not in non-interactive mode.
    if [ "${non_interactive}" = false ]; then
      command_pointer="${main_pointer} ${output_line_number}"
    fi

    # Construct the command array for the current task.
    command_array+=("${RUNAG_TASK[@]:item_pointer:((item_length - (item_pointer - main_pointer - 2)))}")

    # Print the formatted task output.
    echo "${command_pointer:+"${command_pointer} "}${command_array[*]}${end_marker:+" ${end_marker_color}${end_marker}${reset_attrs}"}${comment:+" ${comment_color}# ${comment}${reset_attrs}"}"

    # Increment counters for the next iteration.
    (( output_line_number += 1 ))
    (( main_pointer += item_length + 1 ))
  done
}
