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

# --absorb
# --allow-empty
# --group
# --mode
# --owner
# --keep-permissions
# --sudo
# --source
file::write() {
  local allow_empty=false
  local file_group=""
  local file_mode=""
  local file_owner=""
  local keep_permissions=false
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
  # $2 may also be used further in the function

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

    elif [ "${2+true}" = true ]; then
      printf "%s" "$2" >"${temp_file}" || softfail "Unable to write to temp file" || return $?

    else
      cat >"${temp_file}" || softfail "Unable to write to temp file" || return $?
    fi
  fi

  if [ ! -s "${temp_file}" ] && [ "${allow_empty}" = false ]; then
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
  
file::append_line_unless_present() {
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
  
  local file="$1"
  local string="$2"

  if ! ${perhaps_sudo} test -f "${file}" || ! ${perhaps_sudo} grep -qFx "${string}" "${file}"; then
    <<<"${string}" ${perhaps_sudo} tee -a "${file}" >/dev/null || softfail || return $?
  fi
}

file::update_block() {
  local file_mode=""
  local file_owner=""
  local file_group=""
  local perhaps_sudo=""

  while [[ "$#" -gt 0 ]]; do
    case $1 in
    -m|--mode)
      file_mode="$2"
      shift; shift
      ;;
    -o|--owner)
      file_owner="$2"
      perhaps_sudo=sudo
      shift; shift
      ;;
    -g|--group)
      file_group="$2"
      perhaps_sudo=sudo
      shift; shift
      ;;
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

  local file_path="$1"
  local block_name="$2"

  if [ -z "${file_mode}" ] && ${perhaps_sudo} test -f "${file_path}"; then
    file_mode="$(${perhaps_sudo} stat -c "%a" "${file_path}")" || softfail || return $?
  else
    file_mode="$(file::default_mode ${perhaps_sudo:+"--sudo"})" || softfail || return $?
  fi

  local temp_file; temp_file="$(mktemp)" || softfail || return $?

  file::read_with_updated_block ${perhaps_sudo:+"--sudo"} "${file_path}" "${block_name}" >"${temp_file}" || softfail || return $?

  file::write \
    ${perhaps_sudo:+"--sudo"} \
    ${file_owner:+--owner "${file_owner}"} \
    ${file_group:+--group "${file_group}"} \
    ${file_mode:+--mode "${file_mode}"} \
    --absorb "${temp_file}" "${file_path}" || softfail || return $?
}

file::read_with_updated_block() {
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

  local file_path="$1"
  local block_name="$2"

  if ${perhaps_sudo} test -f "${file_path}"; then
    ${perhaps_sudo} cat "${file_path}" | sed "/^# BEGIN ${block_name}$/,/^# END ${block_name}$/d"
    test "${PIPESTATUS[*]}" = "0 0" || softfail || return $?
  fi

  echo "# BEGIN ${block_name}"
  cat || softfail || return $?
  echo "# END ${block_name}"
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
