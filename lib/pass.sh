#!/usr/bin/env bash

#  Copyright 2012-2022 Stanislav Senotrusov <stan@senotrusov.com>
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

# pass::use secret/path [arguments for pass::use]... foo::bar [arguments for foo::bar]...
#   -b,--body # skip first line and then write the rest of the file contents to foo::bar::save stdin
#   -f,--force # call to ::save if ::exists returns 0
#   -g,--get url # get metadata instead of password
#   -m,--multiline # write all file contents to foo::bar::save stdin
#   -p,--pipe # write secret to foo::bar::save stdin
#   -s,--skip-if-empty
#
# If no foo::bar is provided then write output to stdout
#
# By default it uses only the first line from secret file
#
# At one point I might add support for multiple "--get" and "--get-password"
#
# Example:
#   pass::use secret/path pass::file file/path

pass::use() {
  local secret_path="$1"; shift

  local force_write=false
  local get_body=false
  local get_metadata=false metadata_name
  local get_multiline=false
  local use_pipe=false
  local skip_if_empty=false

  while [[ "$#" -gt 0 ]]; do
    case $1 in
    -b|--body)
      get_body=true
      shift
      ;;
    -f|--force)
      force_write=true
      shift
      ;;
    -g|--get)
      get_metadata=true
      metadata_name="$2"
      shift; shift
      ;;
    -m|--multiline)
      get_multiline=true
      shift
      ;;
    -p|--pipe)
      use_pipe=true
      shift
      ;;
    -s|--skip-if-empty)
      skip_if_empty=true
      shift
      ;;
    -*)
      softfail "Unknown argument: $1" || return $?
      ;;
    *)
      break
      ;;
    esac
  done

  local function_prefix

  if [ -n "${1:-}" ]; then
    function_prefix="$1"; shift
  else
    function_prefix="pass::cat"
  fi

  bash::is-function-or-command-exists "${function_prefix}::exists" || softfail "${function_prefix}::exists should be available as function or command" || return $?
  bash::is-function-or-command-exists "${function_prefix}::save" || softfail "${function_prefix}::save should be available as function or command" || return $?

  if [ "${SOPKA_UPDATE_SECRETS:-}" = "true" ] || [ "${force_write}" = true ] || ! "${function_prefix}::exists" "$@"; then

    local password_store_dir="${PASSWORD_STORE_DIR:-"${HOME}/.password-store"}"
    local secret_file_path="${password_store_dir}/${secret_path}.gpg"

    if [ ! -f "${secret_file_path}" ]; then
      softfail "Unable to find password file: ${secret_file_path}" || return $?
    fi

    if [ "${get_body}" = true ]; then
      pass show "${secret_path}" | tail -n +2 | "${function_prefix}::save" "$@"
      test "${PIPESTATUS[*]}" = "0 0 0" || softfail "Unable to obtain secret from pass and process it in ${function_prefix}::save" || return $?
      return 0
    fi

    if [ "${get_multiline}" = true ]; then
      pass show "${secret_path}" | "${function_prefix}::save" "$@"
      test "${PIPESTATUS[*]}" = "0 0" || softfail "Unable to obtain secret from pass and process it in ${function_prefix}::save" || return $?
      return 0
    fi

    local secret_data

    if [ "${get_metadata}" = true ]; then
      secret_data="$(pass show "${secret_path}" | tail -n +2 | pass::get_metadata "${metadata_name}"; test "${PIPESTATUS[*]}" = "0 0 0")" || softfail "Unable to obtain secret from pass" || return $?
    else
      secret_data="$(pass show "${secret_path}" | head -n1; test "${PIPESTATUS[*]}" = "0 0")" || softfail "Unable to obtain secret from pass" || return $?
    fi
    
    if [ -z "${secret_data}" ]; then
      if [ "${skip_if_empty}" = true ]; then
        return 0
      else
        softfail "Zero-length secret data from pass" || return $?
      fi
    fi

    if [ "${use_pipe}" = true ] || bash::is-function-or-command-exists "${function_prefix}::pipeonly"; then
      <<<"${secret_data}" "${function_prefix}::save" "$@" || softfail "Unable to process secret_data in ${function_prefix}::save" || return $?
    else
      "${function_prefix}::save" "${secret_data}" "$@" || softfail "Unable to process secret_data in ${function_prefix}::save" || return $?
    fi
  fi
}

pass::get_metadata(){
  local match_string="$1"
  local match_string_canonical; match_string_canonical="$(<<<"${match_string}" tr "[:upper:]" "[:lower:]" | sed "s/^[[:blank:]]*//;s/[[:blank:]]*$//"; test "${PIPESTATUS[*]}" = "0 0")" || softfail "Unable to produce match_string_canonical" || return $?

  local line metadata_key
  while IFS="" read -r line; do
    metadata_key="$(<<<"${line}" tr "[:upper:]" "[:lower:]" | cut -s -d ":" -f 1 | sed "s/^[[:blank:]]*//;s/[[:blank:]]*$//"; test "${PIPESTATUS[*]}" = "0 0 0")" || softfail "Unable to produce canonical metadata_key" || return $?
    if [ "${metadata_key}" = "${match_string_canonical}" ]; then
      <<<"${line}" cut -s -d ":" -f 2- | sed "s/^[[:blank:]]*//;s/[[:blank:]]*$//"
      test "${PIPESTATUS[*]}" = "0 0" || softfail "Unable to produce metadata value" || return $?
      return 0
    fi
  done
  return 1
}


# pass::file::exists file/path [options]
# pass::file::save file/path [options]
#   -m,--mode 0600 # file access mode

pass::file::exists() {
  local file_path="$1"

  test -s "${file_path}"
}

pass::file::save() {
  local file_path="$1"; shift

  local file_mode="0600"

  while [[ "$#" -gt 0 ]]; do
    case $1 in
    -m|--mode)
      file_mode="$2"
      shift; shift
      ;;
    -*)
      softfail "Unknown argument: $1" || return $?
      ;;
    *)
      break
      ;;
    esac
  done

  file::write-if-non-zero "${file_path}" "${file_mode}" || softfail "Unable to write secret to file" || return $?
}

pass::file::pipeonly() {
  true
}


# remote_file

pass::remote_file::exists() {
  local file_path="$1"

  ssh::call test -s "${file_path}"
}

pass::remote_file::save() {
  local file_path="$1"; shift

  local file_mode="0600"

  while [[ "$#" -gt 0 ]]; do
    case $1 in
    -m|--mode)
      file_mode="$2"
      shift; shift
      ;;
    -*)
      softfail "Unknown argument: $1" || return $?
      ;;
    *)
      break
      ;;
    esac
  done

  ssh::call file::write-if-non-zero "${file_path}" "${file_mode}" || softfail "Unable to write secret to file" || return $?
}

pass::remote_file::pipeonly() {
  true
}


# cat

pass::cat::exists() {
  false
}

pass::cat::save() {
  cat || softfail "Failed to perform cat " || return $?
}

pass::cat::pipeonly() {
  true
}

# pass::file_with_block::exists file/path block_title [options]
# pass::file_with_block::save file/path block_title [options]
#   -m,--mode 0600 # file access mode

pass::file_with_block::exists() {
  local file_path="$1"
  local block_title="$2"

  test -s "${file_path}" && grep -qFx "${block_title}" "${file_path}"
}

pass::file_with_block::save() {
  local file_path="$1"; shift
  local block_title="$1"; shift

  local file_mode="0600"

  while [[ "$#" -gt 0 ]]; do
    case $1 in
    -m|--mode)
      file_mode="$2"
      shift; shift
      ;;
    -*)
      softfail "Unknown argument: $1" || return $?
      ;;
    *)
      break
      ;;
    esac
  done

  (echo "${block_title}"; cat; echo "${block_title} END") | file::append "${file_path}" "${file_mode}" || softfail "Unable to write secret to file" || return $?
}

pass::file_with_block::pipeonly() {
  true
}
