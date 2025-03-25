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

# TODO: Do I need to account for Directory's Group Ownership with `setgid`?
# TODO: Do I need to account for Group Ownership Propagation via ACL?

# ### `file::write`
#
# Writes data to a file, with options for permissions, ownership, and input sources.
# This function provides multiple methods to write to a file, such as copying, consuming a file,
# capturing output, or writing strings directly. It ensures the file exists with correct properties.
#
# #### Usage
#
# file::write [options]... <file_path> [input_data]
#
# Options:
#   -m, --mode <mode>                Set file permissions in numeric format (e.g., 0644).
#   -o, --owner <owner>              Set the file owner.
#   -g, --group <group>              Set the file group ownership.
#   -s, --sudo                       Use elevated privileges for operations.
#   -r, --root                       Set "root" as the file owner and enable elevated privileges.
#   -u, --user-only                  Restrict access to the current user (default mode: 0600).
#   -d, --mkdir                      Create parent directories if they don't exist.
#   -c, --copy <source_file>         Copy content from an existing file.
#   -n, --consume <source_file>      Move content from an existing file and delete it afterward.
#   -p, --capture                    Capture output from a command to write to the file.
#   -e, --allow-empty                Allow empty input to be written.
#   --<filter-command> [options]...  Apply a filter command to the input data.
#
# #### Example
#
# # Write "Hello, World!" to a file with user-only access
# file::write --user-only /path/to/file "Hello, World!"
#
# # Copy content from an existing file
# file::write --copy /source/file /destination/file
#
# # Capture output of a command
# file::write --capture /path/to/file ls -la

file::write() {
  local mode
  local owner
  local group
  local sudo
  local mkdir=false
  local method
  local source_file
  local allow_empty
  local filter_function
  local filter_arguments_count
  local filter_command=()

  local file_path
  local dir_path
  local dir_mode
  local umask_value
  local temp_file
  local existing_file_temp
  local filter_output_temp

  # Parse arguments
  while [ "$#" -gt 0 ]; do
    case "$1" in
      -m|--mode)
        # Set file permissions in numeric format (e.g., 0644)
        if [ -z "${2:-}" ]; then
          softfail "Error: Missing argument for $1 option" || return $?
        fi
        mode="$2"
        shift 2
        ;;
      -o|--owner)
        # Set the file's owner
        if [ -z "${2:-}" ]; then
          softfail "Error: Missing argument for $1 option" || return $?
        fi
        owner="$2"
        shift 2
        ;;
      -g|--group)
        # Set the file's group ownership
        if [ -z "${2:-}" ]; then
          softfail "Error: Missing argument for $1 option" || return $?
        fi
        group="$2"
        shift 2
        ;;
      -s|--sudo)
        # Enable the use of sudo to perform actions with elevated privileges
        sudo=true
        shift
        ;;
      -r|--root)
        # Assign "root" as the owner of the file and enable the use of elevated privileges.
        # Set the file permissions to 0644 (readable by all, writable by the owner).
        mode="${mode:-0644}"
        owner="root"
        sudo=true
        shift
        ;;
      -u|--user-only)
        # Set default permissions (0600) and ownership to the current user
        mode="${mode:-0600}"
        owner="${USER}"
        shift
        ;;
      -d|--mkdir)
        # Create parent directories if they don't exist.
        mkdir=true
        shift
        ;;
      -c|--copy)
        # Use the "copy" method and specify the source file
        if [ -z "${2:-}" ]; then
          softfail "Error: Missing argument for $1 option" || return $?
        fi
        method="copy"
        source_file="$2"
        shift 2
        ;;
      -n|--consume)
        # Use the "consume" method and specify the source file
        if [ -z "${2:-}" ]; then
          softfail "Error: Missing argument for $1 option" || return $?
        fi
        method="consume"
        source_file="$2"
        shift 2
        ;;
      -p|--capture)
        # Use the "capture" method for handling input
        method="capture"
        shift
        ;;
      -e|--allow-empty)
        # Allow empty content to be written without raising an error
        allow_empty=true
        shift
        ;;
      --*)
        # Handle --option-style arguments by mapping them to compatible filter functions.
        # Strip the leading -- and convert hyphens to underscores to match function names.
        filter_function="${1#--}"
        filter_function="file::write_filter::${filter_function//-/_}"

        # Check if the corresponding filter function is defined
        if ! declare -F "${filter_function}" >/dev/null; then
          # Fail if the filter function for the specified option does not exist
          softfail "Unknown option '${1}' or filter function '${filter_function}' is not defined." || return $?
        fi

        filter_command=("${filter_function}")

        # Remove the first argument (--option)
        shift

        # Let the filter function parse its own arguments and return how many were consumed
        filter_arguments_count="$("${filter_function}" --parse-arguments "$@")" || softfail "Filter argument parsing failed for '${filter_function}'." || return $?

        # Ensure the parsed argument count is a numeric value
        if ! [[ "${filter_arguments_count}" =~ ^[0-9]+$ ]]; then
          softfail "Filter '${filter_function}' returned non-numeric value when parsing arguments." || return $?
        fi

        # Append parsed arguments to the filter command array
        if [ "${filter_arguments_count}" -gt 0 ]; then
          filter_command+=("${@:1:${filter_arguments_count}}")
          shift "${filter_arguments_count}"
        fi
        ;;
      -*)
        # Fail if an unrecognized option is provided
        softfail "Unrecognized option: $1" || return $?
        ;;
      *)
        # Break from the loop when no more options are provided
        break
        ;;
    esac
  done

  # Verify that a file path argument is provided
  if [ -z "${1:-}" ]; then
    softfail "Error: A file path must be provided as an argument." || return $?
  fi

  # Define the file path from the first argument
  file_path="$1"

  shift

  # Set the default method if none is provided
  if [ -z "${method:-}" ]; then
    # Default to the "fetch" method if no arguments are passed
    if [ $# = 0 ]; then
      method="fetch"
    else
      # If arguments are provided, default to the "string" method
      method="string"
    fi
  fi

  # Check if the file exists
  if ${sudo:+"sudo"} test -e "${file_path}"; then
    # Verify that the file is writable
    if ! ${sudo:+"sudo"} test -w "${file_path}"; then
      softfail "The file exists but the user does not have write access: ${file_path}" || return $?
    fi

    # Verify that the file is a regular file
    if ! ${sudo:+"sudo"} test -f "${file_path}"; then
      softfail "The file exists but it is not a regular file: ${file_path}" || return $?
    fi
  fi

  # Check if a source file is specified and ensure it exists and is readable
  if [ -n "${source_file:-}" ] && ! [ -r "${source_file}" ]; then
    # Fail with a error message if the source file is missing or unreadable
    softfail "Source file does not exist or is not readable: ${source_file}" || return $?
  fi

  # Check if the 'mkdir' flag is set to true
  if [ "${mkdir}" = true ]; then
    # Get the directory path from the file path
    dir_path="$(dirname "${file_path}")" || softfail "Failed to determine the directory path from ${file_path}" || return $?

    # If a mode is specified, calculate a compatible directory mode
    if [ -n "${mode:-}" ]; then
      # Convert the mode string to numeric value
      dir_mode=$(( "0${mode}" )) || softfail "Failed to parse mode value: ${mode}" || return $?

      # Ensure the user has execute (search) permission on the directory
      dir_mode=$(( (dir_mode & 0400) == 0400 ? (dir_mode | 0100) : dir_mode )) || \
        softfail "Failed to adjust directory mode for user execute permissions" || return $?

      # Ensure the group has execute (search) permission on the directory
      dir_mode=$(( (dir_mode & 040) == 040 ? (dir_mode | 010) : dir_mode )) || \
        softfail "Failed to adjust directory mode for group execute permissions" || return $?

      # Ensure others have execute (search) permission on the directory
      dir_mode=$(( (dir_mode & 04) == 04 ? (dir_mode | 01) : dir_mode )) || \
        softfail "Failed to adjust directory mode for other execute permissions" || return $?

      # Format the directory mode as an octal string
      printf -v dir_mode "0%o" "${dir_mode}" || softfail "Failed to format directory mode as octal" || return $?
    fi

    # Ensure the directory exists with the specified properties
    dir::ensure_exists \
      ${dir_mode:+--mode "${dir_mode}"} \
      ${owner:+--owner "${owner}"} \
      ${group:+--group "${group}"} \
      ${sudo:+"--sudo"} \
      "${dir_path}" || \
      softfail "Failed to ensure the directory exists: ${dir_path}" || return $?
  fi

  if ${sudo:+"sudo"} test -f "${file_path}"; then
    # Retrieve the current file permissions if the mode is not already specified
    if [ -z "${mode:-}" ]; then
      mode="$(${sudo:+"sudo"} stat -c %a "${file_path}")" || softfail "Failed to retrieve file permissions for ${file_path}" || return $?
    fi

    # Retrieve the current file owner if the owner is not already specified
    if [ -z "${owner:-}" ]; then
      owner="$(${sudo:+"sudo"} stat -c %U "${file_path}")" || softfail "Failed to retrieve file owner for ${file_path}" || return $?
    fi

    # Retrieve the current file group if the group is not already specified
    if [ -z "${group:-}" ]; then
      group="$(${sudo:+"sudo"} stat -c %G "${file_path}")" || softfail "Failed to retrieve file group for ${file_path}" || return $?
    fi
  fi

  # Set the file permissions if the mode is not already specified
  if [ -z "${mode:-}" ]; then
    # Get the umask value depending on whether sudo is used
    if [ "${sudo:-}" = true ]; then
      umask_value="$(sudo --shell umask)" || softfail "Failed to retrieve umask value with sudo" || return $?
    else
      umask_value="$(umask)" || softfail "Failed to retrieve umask value" || return $?
    fi

    # Calculate the mode by applying the umask to the default 0666 permissions
    mode="$(printf "%o" "$(( 0666 ^ "${umask_value}" ))")" || softfail "Failed to calculate mode from umask" || return $?
  fi

  # Set the file owner if the owner is not already specified
  if [ -z "${owner:-}" ]; then
    if [ "${sudo:-}" = true ]; then
      owner=root
    else
      owner="${USER}"
    fi
  fi

  # If no group is set, retrieve the default group for the user
  if [ -z "${group:-}" ]; then
    group="$(id -g -n "${owner}")" || softfail "Failed to retrieve group for owner '${owner}'" || return $?
  fi

  # Create a temporary file and store its path in the temp_file variable
  temp_file="$(mktemp)" || softfail "Failed to create a temporary file" || return $?

  # Handle different input methods based on the specified method
  case "$method" in
    copy|consume)
      # If the method is "copy" or "consume", copy the contents of the source file to the temporary file
      cat "${source_file}" >"${temp_file}" || softfail "Failed to copy data from source file '${source_file}' to temporary file" || return $?
      ;;
    capture)
      # If the method is "capture", capture the command output and write it to the temporary file
      "$@" >"${temp_file}" || softfail "Failed to capture output and write to temporary file" || return $?
      ;;
    fetch)
      # TODO: --terminal-input flag to cancel this check?
      # Check if stdin is a terminal and fail if data input is required
      if [ -t 0 ]; then
        softfail "Stdin cannot be a terminal for file::write. Use a data source or specify a different input method" || return $?
      fi
      # If stdin is not a terminal, capture the input and write it to the temporary file
      cat >"${temp_file}" || softfail "Failed to read input from stdin and write to temporary file" || return $?
      ;;
    string)
      # If the input is a string, write it to the temporary file
      if [ -n "$*" ]; then
        printf "%s\n" "$*" >"${temp_file}" || softfail "Failed to write string data to temporary file" || return $?
      fi
      ;;
    -*)
      # If an unknown method is specified, fail with an error message
      softfail "Unknown input method specified: $1" || return $?
      ;;
  esac

  # Check if a filter command is provided
  if [ ${#filter_command[@]} -gt 0 ]; then
    # If the file exists, copy its content to a temporary file to allow access without sudo privileges
    if ${sudo:+"sudo"} test -f "${file_path}"; then
      existing_file_temp="$(mktemp)" || softfail "Could not create a temporary file to store existing content." || return $?
      ${sudo:+"sudo"} cat "${file_path}" >"${existing_file_temp}" || softfail "Copying existing content to a temporary file did not work." || return $?
    fi

    # Create a temporary file for storing the filtered output
    filter_output_temp="$(mktemp)" || softfail "Something went wrong while creating a temporary file for filtered output." || return $?

    # Apply the filter command to process the content
    "${filter_command[@]}" <"${temp_file}" "${existing_file_temp:-}" >"${filter_output_temp}" || softfail "Filtering process failed to complete successfully." || return $?

    # Replace the temporary file with the filtered output
    mv "${filter_output_temp}" "${temp_file}" || softfail "Could not update the temporary file with the filtered content." || return $?

    # Remove the temporary file for existing content if it was created
    if [ -n "${existing_file_temp:-}" ]; then
      rm "${existing_file_temp}" || softfail "Cleaning up the temporary file for existing content didn't work." || return $?
    fi
  fi

  # Check if empty input is not allowed and the temporary file is empty
  if [ "${allow_empty:-}" != true ] && [ ! -s "${temp_file}" ]; then
    # Remove the temporary file
    rm "${temp_file}" || softfail "Failed to remove the temporary file: ${temp_file}" || return $?

    # Fail with a error message
    softfail "Empty input is not permitted for file::write unless the --allow-empty flag is specified." || return $?
  fi

  # Change the ownership of the temporary file to the specified owner and group
  ${sudo:+"sudo"} chown "${owner}:${group}" "${temp_file}" || \
    softfail "Failed to change ownership of ${temp_file} to ${owner}:${group}" || return $?

  # Set the specified permissions for the temporary file
  ${sudo:+"sudo"} chmod "${mode}" "${temp_file}" || \
    softfail "Failed to set permissions (${mode}) on ${temp_file}" || return $?

  # Move the temporary file to the desired file path
  ${sudo:+"sudo"} mv "${temp_file}" "${file_path}" || \
    softfail "Failed to move ${temp_file} to ${file_path}" || return $?

  # Check if the method is set to "consume"
  if [ "${method}" = consume ]; then
    # Remove the source file as part of the consume operation
    rm "${source_file}" || softfail "Failed to remove the source file: ${source_file}" || return $?
  fi
}

# ## `file::write_filter::append_line_unless_present`
#
# Appends a line from standard input to the file only if it doesn't already exist.
#
# ### Usage
#
# file::write_filter::append_line_unless_present "existing_file"
#
# ### Example
#
# echo "new line" | file::write --append-line-unless-present "/path/to/file"
#
file::write_filter::append_line_unless_present() {
  # If the first argument is --parse-arguments, output the number of arguments this filter consumes and return
  if [ "${1:-}" = "--parse-arguments" ]; then
    echo 0
    return
  fi

  local existing_file="${1:-}"

  # Read the first line from input
  local input_data; input_data="$(head -n 1)" || softfail "Failed to read input data from standard input." || return $?

  if [ -n "${existing_file}" ] && [ -s "${existing_file}" ]; then
    # If the file exists, check if the input line is already present
    if grep -qFx "${input_data}" "${existing_file}"; then
      # Output the current content as no changes are needed
      cat "${existing_file}" || softfail "Failed to read file '${existing_file}'." || return $?
      return
    else
      # Append a newline to the existing content file if the content does not already end with one
      # If the content ends with multiple newlines, they will all be preserved
      sed "\$a\\" "${existing_file}" || softfail "Could not append newline to '${existing_file}'." || return $?
    fi
  fi

  # Output the input line
  printf "%s\n" "${input_data}" || softfail "Failed to write input data to output." || return $?
}

# ## `file::write_filter::section`
#
# Replaces a named section in an existing file with new content from standard input.
# If the section does not exist, appends a new section at the end.
# The section is marked using "# BEGIN <section>" and "# END <section>" lines.
#
# ### Usage
#
# file::write_filter::section <section_name> [existing_file]
#
# ### Example
#
# echo "new content" | file::write --section my-section config-file
#
file::write_filter::section() {
  # If the first argument is --parse-arguments, output the number of arguments this filter consumes and return
  if [ "${1:-}" = "--parse-arguments" ]; then
    echo 1
    return
  fi

  # Validate required arguments
  test -n "${1:-}" || softfail "Section name is required." || return $?

  local section_name="$1"
  local existing_file="${2:-}"

  local existing_lines
  local line
  local state="search"
  # State transitions:
  #   search: Looking for the section start marker
  #   within-section: Skipping lines inside the section
  #   section-found: Copying lines after the section

  if [ -n "${existing_file}" ] && [ -s "${existing_file}" ]; then
    # Read all lines from the file into an array
    # mapfile requires Bash 4.0 or newer (released in 2009)
    mapfile -t existing_lines <"${existing_file}" || softfail "Failed to read content from '${existing_file}'." || return $?

    for line in "${existing_lines[@]}"; do
      case "${state}" in
        search)
          if [ "${line}" = "# BEGIN ${section_name}" ]; then
            state="within-section"
            file::section_envelope "${section_name}" || softfail "Failed to write updated section '${section_name}'." || return $?
          else
            printf '%s\n' "${line}" || softfail "Failed to write preserved line before section '${section_name}'." || return $?
          fi
          ;;
        within-section)
          if [ "${line}" = "# END ${section_name}" ]; then
            state="section-found"
          fi
          ;;
        section-found)
          printf '%s\n' "${line}" || softfail "Failed to write preserved line after section '${section_name}'." || return $?
          ;;
      esac
    done

    case "${state}" in
      within-section)
        # Started section but never found the end marker
        softfail "Section '${section_name}' is missing an end marker." || return $?
        ;;
      section-found)
        return
        ;;
    esac
  fi

  # If no existing section was found, append a new section
  file::section_envelope "${section_name}" || softfail "Failed to append new section '${section_name}'." || return $?
}

# ## `file::section_envelope`
#
# Wraps standard input content with clearly marked section boundaries.
#
# ### Usage
#
# file::section_envelope <section_name>
#
# ### Example
#
# echo "data" | file::section_envelope my-section
#
file::section_envelope() {
  local section_name="$1"

  # Print section start marker
  printf "# BEGIN %s\n" "${section_name}" || softfail "Failed to write start marker for section '${section_name}'." || return $?

  # Ensure a newline at the end of the input, if not already present
  # Preserves any existing trailing newlines
  sed "\$a\\" || softfail "Failed to append newline to input content for section '${section_name}'." || return $?

  # Print section end marker
  printf "# END %s\n" "${section_name}" || softfail "Failed to write end marker for section '${section_name}'." || return $?
}

# ## `file::read_section`
#
# Extracts a named section of lines from a file, delimited by `# BEGIN <name>` and `# END <name>`.
#
# ### Usage
#
# file::read_section "section_name" "file_path"
#
# ### Example
#
# file::read_section "my-section" "/path/to/file"
#
file::read_section() {
  # Check for required arguments
  test -n "${1:-}" || softfail "Section name is required." || return $?
  test -n "${2:-}" || softfail "File path is required." || return $?

  local section_name="$1"
  local file_path="$2"

  # Fail if the specified file does not exist
  if [ ! -f "${file_path}" ]; then
    softfail "File '${file_path}' does not exist." || return $?
  fi

  local file_lines
  local section_lines=()
  local line
  local state="search"
  # State transitions:
  #   search: Looking for the section start marker
  #   within-section: Capturing lines within the section
  #   section-found: End marker found; section complete

  # Read all lines from the file into an array
  # mapfile requires Bash 4.0 or newer (released in 2009)
  mapfile -t file_lines <"${file_path}" || softfail "Failed to read content from '${file_path}'." || return $?

  # Traverse lines to extract the requested section
  for line in "${file_lines[@]}"; do
    case "${state}" in
      search)
        if [ "${line}" = "# BEGIN ${section_name}" ]; then
          state="within-section"
        fi
        ;;
      within-section)
        if [ "${line}" = "# END ${section_name}" ]; then
          state="section-found"
          break
        else
          section_lines+=("${line}")
        fi
        ;;
    esac
  done

  # Fail if no section markers were found
  if [ "${state}" != "section-found" ]; then
    softfail "Section '${section_name}' not found in '${file_path}'." || return $?
  fi

  # Output the extracted lines
  for line in "${section_lines[@]}"; do
    printf "%s\n" "${line}" || softfail "Failed to print content of section '${section_name}'." || return $?
  done
}
