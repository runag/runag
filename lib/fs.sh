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

path::convert_msys_to_windows() {
  echo "$1" | sed "s/^\\/\\([[:alpha:]]\\)\\//\\1:\\//" | sed "s/\\//\\\\/g"
  test "${PIPESTATUS[*]}" = "0 0 0" || softfail || return $?
}  

dir::make_if_not_exists() {
  local dir_path="$1"
  local mode="${2:-}"
  local owner="${3:-}"
  local group="${4:-}"

  if mkdir ${mode:+-m "${mode}"} "${dir_path}" 2>/dev/null; then
    if [ -n "${owner}" ]; then
      chown "${owner}${group:+".${group}"}" "${dir_path}" || softfail || return $?
    fi
  else
    test -d "${dir_path}" || softfail "Unable to create directory, maybe there is a file here already: ${dir_path}" || return $?
  fi
}

dir::make_if_not_exists_and_set_permissions() {
  local dir_path="$1"
  local mode="${2:-}"
  local owner="${3:-}"
  local group="${4:-}"

  if ! mkdir ${mode:+-m "${mode}"} "${dir_path}" 2>/dev/null; then
    test -d "${dir_path}" || softfail "Unable to create directory, maybe there is a file here already: ${dir_path}" || return $?
    chmod "${mode}" "${dir_path}" || softfail || return $?
  fi

  if [ -n "${owner}" ]; then
    chown "${owner}${group:+".${group}"}" "${dir_path}" || softfail || return $?
  fi
}

dir::sudo_make_if_not_exists() {
  local dir_path="$1"
  local mode="${2:-}"
  local owner="${3:-}"
  local group="${4:-}"

  if sudo mkdir ${mode:+-m "${mode}"} "${dir_path}" 2>/dev/null; then
    if [ -n "${owner}" ]; then
      sudo chown "${owner}${group:+".${group}"}" "${dir_path}" || softfail || return $?
    fi
  else
    test -d "${dir_path}" || softfail "Unable to create directory, maybe there is a file here already: ${dir_path}" || return $?
  fi
}

dir::sudo_make_if_not_exists_and_set_permissions() {
  local dir_path="$1"
  local mode="${2:-}"
  local owner="${3:-}"
  local group="${4:-}"

  if ! sudo mkdir ${mode:+-m "${mode}"} "${dir_path}" 2>/dev/null; then
    test -d "${dir_path}" || softfail "Unable to create directory, maybe there is a file here already: ${dir_path}" || return $?
    sudo chmod "${mode}" "${dir_path}" || softfail || return $?
  fi

  if [ -n "${owner}" ]; then
    sudo chown "${owner}${group:+".${group}"}" "${dir_path}" || softfail || return $?
  fi
}

dir::remove_if_exists_and_empty() {
  local dir_path="$1"
  rmdir "${dir_path}" 2>/dev/null || true
}

dir::default_mode() {
  local umask_value; umask_value="$(umask)" || softfail || return $?
  printf "%o" "$(( 0777 ^ "${umask_value}" ))" || softfail || return $?
}

dir::default_mode_with_remote_umask() {
  printf "%o" "$(( 0777 ^ "0${REMOTE_UMASK}" ))" || softfail || return $?
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

  cat >"${temp_file}" || softfail "Unable to write to temp file" || return $?

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
  local string="$1"
  local file="$2"

  if ! test -f "${file}"; then
    fail "File not found: ${file}"
  fi

  if ! grep -qFx "${string}" "${file}"; then
    echo "${string}" | tee -a "${file}" >/dev/null || softfail || return $?
  fi
}

file::sudo_append_line_unless_present() {
  local string="$1"
  local file="$2"

  if ! sudo test -f "${file}"; then
    fail "File not found: ${file}"
  fi
    
  if ! sudo grep -qFx "${string}" "${file}"; then
    echo "${string}" | sudo tee -a "${file}" >/dev/null || softfail || return $?
  fi
}

file::update_block() {
  local file_name="$1"; shift
  local block_name="$1"; shift

  local file_mode=""
  local file_owner=""
  local file_group=""

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

  if [ -z "${file_mode}" ] && [ -f "${file_name}" ]; then
    file_mode="$(stat -c "%a" "${file_name}")" || softfail || return $?
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

mount::wait_until_available() {
  local mountpoint="$1"

  if ! findmnt --mountpoint "${mountpoint}" >/dev/null; then
    echo "Filesystem is not mounted: '${mountpoint}'" >&2
    echo "Please connect the external media if the filesystem resides on it" >&2
    echo "Waiting for the filesystem to be available, press Control-C to interrupt" >&2
  fi

  while ! findmnt --mountpoint "${mountpoint}" >/dev/null; do
    sleep 0.1
  done
}

fs::source() {
  local self_dir
  self_dir="$(dirname "$1")" || softfail "Unable to get dirname of $1" || return $?

  . "${self_dir}/$2" || softfail "Unable to load: ${self_dir}/$2" || return $?
}

fs::recursive_source() {
  local self_dir file_path
  
  self_dir="$(dirname "$1")" || softfail "Unable to get dirname of $1" || return $?

  while IFS= read -r -d '' file_path; do
    . "${file_path}" || softfail "Unable to load: ${file_path}" || return $?
  done < <(find "${self_dir}/$2" -type f -name '*.sh' -print0)
}

fs::get_absolute_path() {
  local relative_path="$1"
  
  # get basename
  local path_basename; path_basename="$(basename "${relative_path}")" \
    || softfail "Sopka: Unable to get a basename of '${relative_path}' ($?)" || return $?

  # get dirname that yet may result to relative path
  local unresolved_dir; unresolved_dir="$(dirname "${relative_path}")" \
    || softfail "Sopka: Unable to get a dirname of '${relative_path}'" || return $?

  # get absolute path
  local resolved_dir; resolved_dir="$(cd "${unresolved_dir}" >/dev/null 2>&1 && pwd)" \
    || softfail "Sopka: Unable to determine absolute path for '${unresolved_dir}'" || return $?

  echo "${resolved_dir}/${path_basename}"
}

fs::with_secure_temp_dir_if_available() {
  if [[ "${OSTYPE}" =~ ^linux ]]; then
    linux::with_secure_temp_dir "$@"
  else
    "$@"
  fi
}

fstab::add_mount_option() {
  local fstype="$1"
  local option="$2"

  local skip; skip="$(<<<"${option}" sed 's/^\([[:alnum:]]\+\).*/\1/')" || softfail || return $?

  sed "/^\(#\|[[:graph:]]\+[[:blank:]]\+[[:graph:]]\+[[:blank:]]\+${fstype}[[:blank:]]\+.*[[:blank:][:punct:]]${skip}\([[:blank:][:punct:]]\|$\)\)/!s/^\([[:graph:]]\+[[:blank:]]\+[[:graph:]]\+[[:blank:]]\+${fstype}[[:blank:]]\+defaults\)\([^[:alnum:]]\|$\)/\1,${option}\2/g;" \
    /etc/fstab | fstab::verify-and-write
    
  test "${PIPESTATUS[*]}" = "0 0" || softfail "Error adding mount option to /etc/fstab" || return $?
}

fstab::verify-and-write() {
  local temp_file; temp_file="$(mktemp)" || softfail || return $?

  cat >"${temp_file}" || softfail "Error writing to temp file: ${temp_file}" || return $?

  test -s "${temp_file}" || softfail "Error: fstab candidate should have size greater that zero: ${temp_file}" || return $?
  
  findmnt --verify --tab-file "${temp_file}" 2>&1 || softfail "Failed to verify fstab candidate: ${temp_file}" || return $?

  sudo install -o root -g root -m 0664 -C "${temp_file}" /etc/fstab || softfail "Failed to install new fstab: ${temp_file}" || return $?

  rm "${temp_file}" || softfail "Failed to remove temp file: ${temp_file}" || return $?
}

symlink::update_link_to_current() {
  local target_thing="$1"
  local link_name="$2"

  if [ -e "${link_name}" ] && [ ! -L "${link_name}" ]; then
    softfail "Unable to create/update a link to a current thing, some non-link file exists: ${link_name}"
    return $?
  fi

  ln --symbolic --force --no-dereference "${target_thing}" "${link_name}" || softfail || return $?
}
