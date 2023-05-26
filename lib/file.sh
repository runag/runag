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

# --mode
# --owner
# --group
# --sudo
# --keep-permissions
# --allow-empty
file::write() {
  local file_mode=""
  local file_owner=""
  local file_group=""
  local perhaps_sudo=""
  local keep_permissions=false
  local allow_empty=false

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
    -k|--keep-permissions)
      keep_permissions=true
      shift
      ;;
    -e|--allow-empty)
      allow_empty=true
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

  local temp_file; temp_file="$(mktemp)" || softfail || return $?

  if [ "${2+true}" = true ]; then
    printf "%s" "$2" >"${temp_file}" || softfail "Unable to write to temp file" || return $?
  else
    cat >"${temp_file}" || softfail "Unable to write to temp file" || return $?
  fi

  if [ ! -s "${temp_file}" ] && [ "${allow_empty}" = false ]; then
    rm "${temp_file}" || softfail || return $?
    softfail "Empty input for file::write" || return $?
  fi

  ${perhaps_sudo} install ${file_owner:+-o "${file_owner}"} ${file_group:+-g "${file_group}"} ${file_mode:+-m "${file_mode}"} -C "${temp_file}" "${file_path}" || softfail || return $?
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

  ${perhaps_sudo} install ${file_owner:+-o "${file_owner}"} ${file_group:+-g "${file_group}"} ${file_mode:+-m "${file_mode}"} -C "${temp_file}" "${file_path}" || softfail || return $?
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
