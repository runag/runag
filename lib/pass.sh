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

pass::each() {
  local test_expression="-f"
  local search_extension=".gpg"

  while [ "$#" -gt 0 ]; do
    case "$1" in
      -d|--dir|--directory)
        test_expression="-d"
        search_extension=""
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

  local search_path="$1"; shift

  local password_store_dir; password_store_dir="$(realpath "${PASSWORD_STORE_DIR:-"${HOME}/.password-store"}")"
  local absolute_search_path; absolute_search_path="$(realpath "${password_store_dir}/${search_path}")" || softfail || return $?

  local found_path; for found_path in "${absolute_search_path}"/*"${search_extension}"; do
    if test "${test_expression}" "${found_path}"; then
      local found_relative_path="${found_path:$((${#password_store_dir}+1))}"

      if [ "${test_expression}" = "-f" ]; then
        local dir_name; dir_name="$(dirname "${found_relative_path}")" || softfail || return $?
        local base_name; base_name="$(basename -s .gpg "${found_relative_path}")" || softfail || return $?
        found_relative_path="${dir_name}/${base_name}"
      fi
      
      "$@" "${found_relative_path}"
      softfail --unless-good --status $? || exit $?
    fi
  done
}

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
#   -b,--body               # skip first line and then write the rest of the file contents to stdout
#   -g,--get name           # get metadata instead of password
#   -m,--multiline          # write all file contents to stdout
#   -e,--skip-if-empty      # do not call callback function if secret is empty
#   -x,--skip-if-not-exists # do not call callback function if secret not exists
#   -u,--skip-update        # do not call callback function if call to "${callback_function}::exists" returns 0
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
#
pass::use() {
  # parse arguments
  local get_body=false
  local get_metadata=false metadata_name
  local get_multiline=false
  local skip_if_empty=false
  local skip_if_not_exists=false
  local skip_update=false
  local absorb_in_callback=false

  while [ "$#" -gt 0 ]; do
    case "$1" in
      -a|--consume-in-callback)
        absorb_in_callback=true
        shift
        ;;
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
      -x|--skip-if-not-exists)
        skip_if_not_exists=true
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
    if [ "${skip_if_not_exists}" = true ]; then
      return 0
    else
      softfail "Unable to find password file: ${secret_file_path}" || return $?
    fi
  fi

  if [ "${get_body}" = true ] || [ "${get_multiline}" = true ]; then

    if [ "${absorb_in_callback}" = true ]; then
      if [ -z "${callback_function}" ]; then
        softfail "Callback function should be specified" || return $?
      fi

      local temp_file; temp_file="$(mktemp)" || softfail || return $?

      if [ "${get_body}" = true ]; then
        pass show "${secret_path}" | tail -n +2 >"${temp_file}"
        test "${PIPESTATUS[*]}" = "0 0" || softfail "Unable to obtain secret from pass" || return $?
      else
        pass show "${secret_path}" >"${temp_file}" || softfail || return $?
      fi

      if [ -f "${temp_file}" ] && [ ! -s "${temp_file}" ]; then
        if [ "${skip_if_empty}" = true ]; then
          return 0
        fi
        softfail "Zero-length secret data from pass" || return $?
      fi

      "${callback_function}" --consume "${temp_file}" "$@"
      softfail --unless-good --status $? "Unable to process secret data in ${callback_function} ($?)" || return $?

      return 0
    fi

    # I don't want to hack a way to peek into the pipe nor do I want to keep secret in a temp file or run pass show twice in case if someone need to confirm on each access
    if [ "${skip_if_empty}" = true ]; then
      softfail "--skip-if-empty is not supported for pipe output" || return $?
    fi

    if [ -n "${callback_function}" ]; then
      # pipe secret data to callback function
      if [ "${get_body}" = true ]; then
        pass show "${secret_path}" | tail -n +2 | "${callback_function}" "$@"
        test "${PIPESTATUS[*]}" = "0 0 0" || softfail "Unable to obtain secret from pass and process it with the callback function: ${callback_function}" || return $?
      else
        pass show "${secret_path}" | "${callback_function}" "$@"
        test "${PIPESTATUS[*]}" = "0 0" || softfail "Unable to obtain secret from pass and process it with the callback function: ${callback_function}" || return $?
      fi
    else
      # pipe secret data to stdout
      if [ "${get_body}" = true ]; then
        pass show "${secret_path}" | tail -n +2
        test "${PIPESTATUS[*]}" = "0 0" || softfail "Unable to obtain secret from pass" || return $?
      else
        pass show "${secret_path}" || softfail "Unable to obtain secret from pass" || return $?
      fi
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
    "${callback_function}" "$@" "${secret_data}"
    softfail --unless-good --status $? "Unable to process secret data in ${callback_function} ($?)" || return $?
  else
    printf "%s" "${secret_data}" || softfail || return $?
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

pass::install_fzf_extension() {
  local extension_name="${1:-ff}"

  local temp_file; temp_file="$(mktemp)" || fail
  {
    printf "#!/usr/bin/env bash\n\n" || fail
    runag::print_license && printf "\n" || fail

    cat <<'SHELL'
pass_name=$(cd "${PREFIX}" && find -name "*.gpg" | cut -c 3- | sed 's/\.gpg$//' | fzf --query "$*" --select-1) || exit $?

pass show --clip "${pass_name}" && printf "\n"
pass show "${pass_name}" | tail -n +2
SHELL
  } >"${temp_file}" || fail

  file::write --consume "${temp_file}" --sudo --mode 0755 "/usr/lib/password-store/extensions/${extension_name}.bash" || fail
}
