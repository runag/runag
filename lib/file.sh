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
  local umask_value; umask_value="$(umask)" || softfail || return $?
  printf "%o" "$(( 0666 ^ "${umask_value}" ))" || softfail || return $?
}

file::sudo_write() {
  local dest="$1"
  local mode="${2:-}"
  local owner="${3:-}"
  local group="${4:-}"

  if [ -n "${mode}" ] || [ -n "${owner}" ] || [ -n "${group}" ]; then
    # I want to create a file with the right mode right away
    # the use of "install" command performs that, at least on linux and macos
    # it creates a file with the mode 600, which is good, and then it changes the mode to the one provided in the argument
    # it's probably better to make it different, like calculate umask and then "cat" to it, but I don't have time to think about that right now
    sudo install ${mode:+-m "${mode}"} ${owner:+-o "${owner}"} ${group:+-g "${group}"} /dev/null "${dest}" || softfail || return $?
  fi

  cat | sudo tee "${dest}" >/dev/null
  test "${PIPESTATUS[*]}" = "0 0" || softfail || return $?
}

file::write() {
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

  local file_path="$1"

  local temp_file; temp_file="$(mktemp)" || softfail || return $?

  if [ "${2+true}" = true ]; then
    printf "%s" "$2" >"${temp_file}" || softfail "Unable to write to temp file" || return $?
  else
    cat >"${temp_file}" || softfail "Unable to write to temp file" || return $?
  fi

  if [ ! -s "${temp_file}" ]; then
    rm "${temp_file}" || softfail || return $?
    softfail "Zero-length input" || return $?
  fi

  if [ -n "${file_mode}" ]; then
    chmod "${file_mode}" "${temp_file}" || softfail || return $?
  fi
  
  mv "${temp_file}" "${file_path}" || softfail || return $?
}

file::append() {
  local dest="$1"
  local mode="${2:-}"

  if [ -n "${mode}" ] && [ ! -f "${dest}" ]; then
    # I want to create a file with the right mode right away
    # the use of "install" command performs that, at least on linux and macos
    # it creates a file with the mode 600, which is good, and then it changes the mode to the one provided in the argument
    # it's probably better to make it different, like calculate umask and then "cat" to it, but I don't have time to think about that right now
    install -m "${mode}" /dev/null "${dest}" || softfail "Unable to create file" || return $?
  fi

  tee -a "${dest}" >/dev/null || softfail "Unable to write to file" || return $?
}

file::append_line_unless_present() {
  local file="$1"
  local string="$2"

  if ! test -f "${file}" || ! grep -qFx "${string}" "${file}"; then
    echo "${string}" | tee -a "${file}" >/dev/null || softfail || return $?
  fi
}

file::sudo_append_line_unless_present() {
  local file="$1"
  local string="$2"

  if ! sudo test -f "${file}" || ! sudo grep -qFx "${string}" "${file}"; then
    echo "${string}" | sudo tee -a "${file}" >/dev/null || softfail || return $?
  fi
}

file::update_block() {
  local file_mode file_owner file_group

  while [[ "$#" -gt 0 ]]; do
    case $1 in
    -m|--mode)
      file_mode="$2"
      shift; shift
      ;;
    -o|--owner)
      file_owner="$2"
      shift; shift
      ;;
    -g|--group)
      file_group="$2"
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

  local file_name="$1"
  local block_name="$2"

  if [ -z "${file_mode:-}" ] && [ -f "${file_name}" ]; then
    file_mode="$(stat -c "%a" "${file_name}")" || softfail || return $?
  else
    file_mode="$(file::default_mode)" || softfail || return $?
  fi

  local temp_file; temp_file="$(mktemp)" || softfail || return $?

  file::read_with_updated_block "${file_name}" "${block_name}" ${file_owner:+"--sudo"} >"${temp_file}" || softfail || return $?

  ${file_owner:+"sudo"} install ${file_owner:+-o "${file_owner}"} ${file_group:+-g "${file_group}"} ${file_mode:+-m "${file_mode}"} -C "${temp_file}" "${file_name}" || softfail || return $?
}

file::read_with_updated_block() {
  local file_name="$1"
  local block_name="$2"

  local perhaps_sudo=""

  if [ "${3:-}" = "--sudo" ]; then
    perhaps_sudo=sudo
  fi

  if [ -f "${file_name}" ]; then
    ${perhaps_sudo} cat "${file_name}" | sed "/^# BEGIN ${block_name}$/,/^# END ${block_name}$/d"
    test "${PIPESTATUS[*]}" = "0 0" || softfail || return $?
  fi

  echo "# BEGIN ${block_name}"

  cat || softfail || return $?

  echo "# END ${block_name}"
}

file::get_block() {
  local file_name="$1"
  local block_name="$2"

  if [ -f "${file_name}" ]; then
    <"${file_name}" sed -n "/^# BEGIN ${block_name}$/,/^# END ${block_name}$/p" || softfail || return $?
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
