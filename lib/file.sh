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

file::default_mode() {
  local perhaps_sudo=""

  while [[ "$#" -gt 0 ]]; do
    case $1 in
    -s|--sudo)
      perhaps_sudo=sudo
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

  local umask_value
  
  if [ "${perhaps_sudo}" = sudo ]; then
    umask_value="$(sudo /usr/bin/sh -c umask)" || softfail || return $?
  else
    umask_value="$(umask)" || softfail || return $?
  fi

  printf "%o" "$(( 0666 ^ "${umask_value}" ))" || softfail || return $?
}

# file::write
#   --absorb
#   --allow-empty
#   --group
#   --mode
#   --owner
#   --keep-permissions
#   --sudo
#   --source
#   file_path
#   [content_string]
#
file::write() {
  local allow_empty=""
  local file_group=""
  local file_mode=""
  local file_owner=""
  local keep_permissions=""
  local perhaps_sudo=""
  local source_file=""
  local temp_file=""

  while [[ "$#" -gt 0 ]]; do
    case $1 in
    -a|--absorb)
      temp_file="$2"
      shift; shift
      ;;
    -e|--allow-empty)
      allow_empty=true
      shift
      ;;
    -g|--group)
      file_group="$2"
      shift; shift
      ;;
    -m|--mode)
      file_mode="$2"
      shift; shift
      ;;
    -o|--owner)
      file_owner="$2"
      shift; shift
      ;;
    -k|--keep-permissions)
      keep_permissions=true
      shift
      ;;
    -u|--sudo)
      perhaps_sudo=sudo
      shift
      ;;
    -s|--source)
      source_file="$2"
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

  local file_path="$1"
  local content_string="${2:-}"

  if [ "${keep_permissions}" = true ] && ${perhaps_sudo} test -f "${file_path}"; then
    file_mode="$(${perhaps_sudo} stat -c "%a" "${file_path}")" || softfail || return $?
  fi

  if [ -z "${file_mode}" ]; then
    if ${perhaps_sudo} test -f "${file_path}"; then
      file_mode="$(${perhaps_sudo} stat -c "%a" "${file_path}")" || softfail || return $?
    else
      file_mode="$(file::default_mode ${perhaps_sudo:+"--sudo"})" || softfail || return $?
    fi
  fi

  if [ -z "${temp_file}" ]; then
    temp_file="$(mktemp)" || softfail || return $?

    if [ -n "${source_file}" ]; then
      cp "${source_file}" "${temp_file}" || softfail "Unable to copy from source file" || return $?

    elif [ "${content_string:+true}" = true ]; then
      echo "$content_string" >"${temp_file}" || softfail "Unable to write to temp file" || return $?

    else
      cat >"${temp_file}" || softfail "Unable to write to temp file" || return $?
    fi
  fi

  if [ ! -r "${temp_file}" ]; then
    softfail "Unable to read temporary file: ${temp_file}" || return $?
  fi

  if [ ! -s "${temp_file}" ] && [ "${allow_empty}" != true ]; then
    rm "${temp_file}" || softfail || return $?
    softfail "Empty input for file::write" || return $?
  fi

  if [ -n "${file_owner}" ]; then
    ${perhaps_sudo} chown "${file_owner}${file_group:+".${file_group}"}" "${temp_file}" || softfail || return $?
  elif [ -n "${file_group}" ]; then
    ${perhaps_sudo} chgrp "${file_group}" "${temp_file}" || softfail || return $?
  fi

  ${perhaps_sudo} chmod "${file_mode}" "${temp_file}" || softfail || return $?

  ${perhaps_sudo} mv "${temp_file}" "${file_path}" || softfail || return $?
}

# file::append_line_unless_present
#   --group
#   --mode
#   --owner
#   --keep-permissions
#   --sudo
#   file_path
#   [line_content]
# 
file::append_line_unless_present() {
  local file_group=""
  local file_mode=""
  local file_owner=""
  local keep_permissions=""
  local perhaps_sudo=""

  while [[ "$#" -gt 0 ]]; do
    case $1 in
    -g|--group)
      file_group="$2"
      shift; shift
      ;;
    -m|--mode)
      file_mode="$2"
      shift; shift
      ;;
    -o|--owner)
      file_owner="$2"
      shift; shift
      ;;
    -k|--keep-permissions)
      keep_permissions=true
      shift
      ;;
    -u|--sudo)
      perhaps_sudo=sudo
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
  
  local file_path="$1"
  local line_content="$2"

  if ! ${perhaps_sudo} test -f "${file_path}" || ! ${perhaps_sudo} grep -qFx "${line_content}" "${file_path}"; then

    if [ "${keep_permissions}" = true ] && ${perhaps_sudo} test -f "${file_path}"; then
      file_mode="$(${perhaps_sudo} stat -c "%a" "${file_path}")" || softfail || return $?
    fi

    temp_file="$(mktemp)" || softfail || return $?

    if ${perhaps_sudo} test -f "${file_path}"; then
      ${perhaps_sudo} cat "${file_path}" | sed '$a\' >"${temp_file}"
      test "${PIPESTATUS[*]}" = "0 0" || softfail || return $?
    fi

    echo "${line_content}" >>"${temp_file}" || softfail || return $?

    file::write \
      ${perhaps_sudo:+"--sudo"} \
      ${file_owner:+--owner "${file_owner}"} \
      ${file_group:+--group "${file_group}"} \
      ${file_mode:+--mode "${file_mode}"} \
      --absorb "${temp_file}" "${file_path}" || softfail || return $?
  fi
}

# file::update_block
#   --absorb
#   --allow-empty
#   --group
#   --mode
#   --owner
#   --keep-permissions
#   --sudo
#   --source
#   file_path
#   block_name
#   [content_string]
#
file::update_block() {
  local allow_empty=""
  local file_group=""
  local file_mode=""
  local file_owner=""
  local keep_permissions=""
  local perhaps_sudo=""
  local source_file=""
  local temp_file=""

  while [[ "$#" -gt 0 ]]; do
    case $1 in
    -a|--absorb)
      temp_file="$2"
      shift; shift
      ;;
    -e|--allow-empty)
      allow_empty=true
      shift
      ;;
    -g|--group)
      file_group="$2"
      shift; shift
      ;;
    -m|--mode)
      file_mode="$2"
      shift; shift
      ;;
    -o|--owner)
      file_owner="$2"
      shift; shift
      ;;
    -k|--keep-permissions)
      keep_permissions=true
      shift
      ;;
    -u|--sudo)
      perhaps_sudo=sudo
      shift
      ;;
    -s|--source)
      source_file="$2"
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

  local file_path="$1"
  local block_name="$2"
  local content_string="${3:-}"

  if [ "${keep_permissions}" = true ] && ${perhaps_sudo} test -f "${file_path}"; then
    file_mode="$(${perhaps_sudo} stat -c "%a" "${file_path}")" || softfail || return $?
  fi

  if [ -z "${file_mode}" ]; then
    if ${perhaps_sudo} test -f "${file_path}"; then
      file_mode="$(${perhaps_sudo} stat -c "%a" "${file_path}")" || softfail || return $?
    else
      file_mode="$(file::default_mode ${perhaps_sudo:+"--sudo"})" || softfail || return $?
    fi
  fi

  local result_temp_file; result_temp_file="$(mktemp)" || softfail || return $?

  file::read_with_updated_block \
    ${temp_file:+"--absorb" "${temp_file}"} \
    ${allow_empty:+"--allow-empty"} \
    ${perhaps_sudo:+"--sudo"} \
    ${source_file:+"--source" "${source_file}"} \
    "${file_path}" "${block_name}" ${content_string:+"${content_string}"} >"${result_temp_file}" || softfail || return $?

  file::write \
    ${perhaps_sudo:+"--sudo"} \
    ${file_owner:+--owner "${file_owner}"} \
    ${file_group:+--group "${file_group}"} \
    ${file_mode:+--mode "${file_mode}"} \
    --absorb "${result_temp_file}" "${file_path}" || softfail || return $?
}

file::read_with_updated_block() {
  local allow_empty=""
  local perhaps_sudo=""
  local source_file=""
  local temp_file=""

  while [[ "$#" -gt 0 ]]; do
    case $1 in
    -a|--absorb)
      temp_file="$2"
      shift; shift
      ;;
    -e|--allow-empty)
      allow_empty=true
      shift
      ;;
    -u|--sudo)
      perhaps_sudo=sudo
      shift
      ;;
    -s|--source)
      source_file="$2"
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

  local file_path="$1"
  local block_name="$2"
  local content_string="${3:-}"

  if ${perhaps_sudo} test -f "${file_path}"; then
    ${perhaps_sudo} cat "${file_path}" | sed '$a\' | sed "/^# BEGIN ${block_name}$/,/^# END ${block_name}$/d"
    test "${PIPESTATUS[*]}" = "0 0 0" || softfail || return $?
  fi

  if [ -z "${temp_file}" ]; then
    temp_file="$(mktemp)" || softfail || return $?

    if [ -n "${source_file}" ]; then
      cp "${source_file}" "${temp_file}" || softfail "Unable to copy from source file" || return $?

    elif [ "${content_string:+true}" = true ]; then
      echo "$content_string" >"${temp_file}" || softfail "Unable to write to temp file" || return $?

    else
      cat >"${temp_file}" || softfail "Unable to write to temp file" || return $?
    fi
  fi

  if [ ! -r "${temp_file}" ]; then
    softfail "Unable to read temporary file: ${temp_file}" || return $?
  fi

  if [ ! -s "${temp_file}" ] && [ "${allow_empty}" != true ]; then
    rm "${temp_file}" || softfail || return $?
    softfail "Empty input for file::write" || return $?
  fi

  echo "# BEGIN ${block_name}"
  <"${temp_file}" sed '$a\' || softfail || return $?
  echo "# END ${block_name}"

  rm "${temp_file}" || softfail || return $?
}

file::get_block() {
  local file_path="$1"
  local block_name="$2"

  if [ -f "${file_path}" ]; then
    <"${file_path}" sed -n "/^# BEGIN ${block_name}$/,/^# END ${block_name}$/p" || softfail || return $?
  fi
}

file::wait_until_available() {
  local file_path="$1"

  if [ ! -e "${file_path}" ]; then
    echo "File not found: '${file_path}'" >&2
    echo "Please connect the external media if the file resides on it" >&2
    echo "Waiting for the file to be available, press Control-C to interrupt" >&2
  fi

  while [ ! -e "${file_path}" ]; do
    sleep 0.1
  done
}
