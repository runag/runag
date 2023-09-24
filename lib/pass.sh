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

pass::exists() {
  local secret_path="$1"
  local password_store_dir="${PASSWORD_STORE_DIR:-"${HOME}/.password-store"}"

  if [ -d "${password_store_dir}/${secret_path}" ] || [ -f "${password_store_dir}/${secret_path}".gpg ]; then
    return 0
  else
    return 1
  fi
}

pass::dir_exists() {
  local secret_path="$1"
  local password_store_dir="${PASSWORD_STORE_DIR:-"${HOME}/.password-store"}"

  if [ -d "${password_store_dir}/${secret_path}" ]; then
    return 0
  else
    return 1
  fi
}

pass::secret_exists() {
  local secret_path="$1"
  local password_store_dir="${PASSWORD_STORE_DIR:-"${HOME}/.password-store"}"

  if [ -f "${password_store_dir}/${secret_path}".gpg ]; then
    return 0
  else
    return 1
  fi
}

# pass::use [arguments for pass::use]... secret/path [callback_function] [arguments for callback_function]...
#   -b,--body          # skip first line and then write the rest of the file contents to stdout
#   -g,--get name      # get metadata instead of password
#   -m,--multiline     # write all file contents to stdout
#   -e,--skip-if-empty # do not call callback function if secret is empty
#   -u,--skip-update   # do not call callback function if call to "${callback_function}::exists" returns 0
#
# If no callback_function is provided then write output to stdout
#
# By default it uses only the first line from secret file
#
# Example:
#   pass::use secret/path | file::write file/path
#   pass::use secret/path | ssh::call file::write file/path
#   pass::use secret/path file::write file/path
#   pass::use secret/path ssh::call file::write file/path
#   pass::use secret/path use_password_somewhere

pass::use() {

  # parse arguments
  local get_body=false
  local get_metadata=false metadata_name
  local get_multiline=false
  local skip_if_empty=false
  local skip_update=false

  while [[ "$#" -gt 0 ]]; do
    case $1 in
    -b|--body)
      get_body=true
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
    -e|--skip-if-empty)
      skip_if_empty=true
      shift
      ;;
    -u|--skip-update)
      skip_update=true
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

  local secret_path="$1"; shift
  local callback_function="${1:-}"; shift


  # determine if we should skip update
  if [ "${skip_update}" = true ]; then
    if [ -z "${callback_function}" ]; then
      softfail "Callback function name should be specified" || return $?
    fi

    if ! declare -F "${callback_function}::exists" >/dev/null && ! command -v "${callback_function}::exists" >/dev/null; then
      softfail "${callback_function}::exists should be available as function or command" || return $?
    fi

    if "${callback_function}::exists" "$@"; then
      return 0
    fi
  fi

  # find the password file
  local password_store_dir="${PASSWORD_STORE_DIR:-"${HOME}/.password-store"}"
  local secret_file_path="${password_store_dir}/${secret_path}.gpg"

  if [ ! -f "${secret_file_path}" ]; then
    softfail "Unable to find password file: ${secret_file_path}" || return $?
  fi

  # case if "--multiline" specified
  if [ "${get_multiline}" = true ]; then
    # I don't want to hack a way to peek into the pipe nor do I want to keep secret in a temp file or run pass show twice in case if someone need to confirm on each access
    if [ "${skip_if_empty}" = true ]; then
      softfail "--skip-if-empty is not supported for pipe output" || return $?
    fi
    
    if [ -n "${callback_function}" ]; then
      # pipe secret data to callback function
      pass show "${secret_path}" | "${callback_function}" "$@"
      test "${PIPESTATUS[*]}" = "0 0 0" || softfail "Unable to obtain secret from pass and process it with the callback function: ${callback_function}" || return $?

    else
      # pipe secret data to stdout
      pass show "${secret_path}"
      test "${PIPESTATUS[*]}" = "0 0" || softfail "Unable to obtain secret from pass" || return $?
    fi

    return 0
  fi

  # case if "--body" specified
  if [ "${get_body}" = true ]; then
    # I don't want to hack a way to peek into the pipe nor do I want to keep secret in a temp file or run pass show twice in case if someone need to confirm on each access
    if [ "${skip_if_empty}" = true ]; then
      softfail "--skip-if-empty is not supported for pipe output" || return $?
    fi

    if [ -n "${callback_function}" ]; then
      # pipe secret data to callback function
      pass show "${secret_path}" | tail -n +2 | "${callback_function}" "$@"
      test "${PIPESTATUS[*]}" = "0 0 0" || softfail "Unable to obtain secret from pass and process it with the callback function: ${callback_function}" || return $?

    else
      # pipe secret data to stdout
      pass show "${secret_path}" | tail -n +2
      test "${PIPESTATUS[*]}" = "0 0" || softfail "Unable to obtain secret from pass" || return $?
    fi

    return 0
  fi

  # obtain secret data
  local secret_data

  if [ "${get_metadata}" = true ]; then
    secret_data="$(pass show "${secret_path}" | tail -n +2 | pass::get_metadata "${metadata_name}"; test "${PIPESTATUS[*]}" = "0 0 0")" || softfail "Unable to obtain secret from pass" || return $?
  else
    secret_data="$(pass show "${secret_path}" | head -n1; test "${PIPESTATUS[*]}" = "0 0")" || softfail "Unable to obtain secret from pass" || return $?
  fi

  # if data have length of zero
  if [ -z "${secret_data}" ]; then
    if [ "${skip_if_empty}" = true ]; then
      if [ -n "${callback_function}" ]; then
        return 0
      fi
      softfail "--skip-if-empty is not supported for pipe output" || return $?
    fi
    softfail "Zero-length secret data from pass" || return $?
  fi

  # run callback function
  if [ -n "${callback_function}" ]; then
    "${callback_function}" "$@" "${secret_data}" || softfail "Unable to process secret data in ${callback_function}" || return $?
  else
    printf "%s" "${secret_data}" || softfail "Unable to process secret data in ${callback_function}" || return $?
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
