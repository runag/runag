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
  test "${PIPESTATUS[*]}" = "0 0 0" || fail
}  

dir::make_if_not_exists() {
  local dir_path="$1"
  local mode="${2:-}"
  local owner="${3:-}"
  local group="${4:-}"

  if mkdir ${mode:+-m "${mode}"} "${dir_path}" 2>/dev/null; then
    if [ -n "${owner}" ]; then
      chown "${owner}${group:+".${group}"}" "${dir_path}" || fail
    fi
  else
    test -d "${dir_path}" || fail "Unable to create directory, maybe there is a file here already: ${dir_path}"
  fi
}

dir::make_if_not_exists_and_set_permissions() {
  local dir_path="$1"
  local mode="${2:-}"
  local owner="${3:-}"
  local group="${4:-}"

  if ! mkdir ${mode:+-m "${mode}"} "${dir_path}" 2>/dev/null; then
    test -d "${dir_path}" || fail "Unable to create directory, maybe there is a file here already: ${dir_path}"
    chmod "${mode}" "${dir_path}" || fail
  fi

  if [ -n "${owner}" ]; then
    chown "${owner}${group:+".${group}"}" "${dir_path}" || fail
  fi
}

dir::sudo_make_if_not_exists() {
  local dir_path="$1"
  local mode="${2:-}"
  local owner="${3:-}"
  local group="${4:-}"

  if sudo mkdir ${mode:+-m "${mode}"} "${dir_path}" 2>/dev/null; then
    if [ -n "${owner}" ]; then
      sudo chown "${owner}${group:+".${group}"}" "${dir_path}" || fail
    fi
  else
    test -d "${dir_path}" || fail "Unable to create directory, maybe there is a file here already: ${dir_path}"
  fi
}

dir::sudo_make_if_not_exists_and_set_permissions() {
  local dir_path="$1"
  local mode="${2:-}"
  local owner="${3:-}"
  local group="${4:-}"

  if ! sudo mkdir ${mode:+-m "${mode}"} "${dir_path}" 2>/dev/null; then
    test -d "${dir_path}" || fail "Unable to create directory, maybe there is a file here already: ${dir_path}"
    sudo chmod "${mode}" "${dir_path}" || fail
  fi

  if [ -n "${owner}" ]; then
    sudo chown "${owner}${group:+".${group}"}" "${dir_path}" || fail
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
    sudo install ${mode:+-m "${mode}"} ${owner:+-o "${owner}"} ${group:+-g "${group}"} /dev/null "${dest}" || fail
  fi

  cat | sudo tee "${dest}" >/dev/null
  test "${PIPESTATUS[*]}" = "0 0" || fail
}

file::write() {
  local dest="$1"
  local mode="${2:-}"

  if [ -n "${mode}" ]; then
    # I want to create a file with the right mode right away
    # the use of "install" command performs that, at least on linux and macos
    # it creates a file with the mode 600, which is good, and then it changes the mode to the one provided in the argument
    # it's probably better to make it different, like calculate umask and then "cat" to it, but I don't have time to think about that right now
    install -m "${mode}" /dev/null "${dest}" || fail
  fi

  cat >"${dest}" || fail
}

file::write-if-non-zero() {
  local dest="$1"
  local mode="${2:-}"

  if [ -n "${mode}" ]; then
    # I want to create a file with the right mode right away
    # the use of "install" command performs that, at least on linux and macos
    # it creates a file with the mode 600, which is good, and then it changes the mode to the one provided in the argument
    # it's probably better to make it different, like calculate umask and then "cat" to it, but I don't have time to think about that right now
    install -m "${mode}" /dev/null "${dest}.sopka-temp" || softfail "Unable to create temp file" || return $?
  fi

  cat >"${dest}.sopka-temp" || softfail "Unable to write to temp file" || return $?

  if [ -s "${dest}.sopka-temp" ]; then
    mv "${dest}.sopka-temp" "${dest}" || softfail "Unable to move temp file to the output file" || return $?
  else
    rm "${dest}.sopka-temp" || softfail "Unable to remove temp file" || return $?
    softfail "Zero-length input writing file" || return $?
  fi
}

file::append_line_unless_present() {
  local string="$1"
  local file="$2"

  if ! test -f "${file}"; then
    fail "File not found: ${file}"
  fi

  if ! grep -qFx "${string}" "${file}"; then
    echo "${string}" | tee -a "${file}" >/dev/null || fail
  fi
}

file::sudo_append_line_unless_present() {
  local string="$1"
  local file="$2"

  if ! sudo test -f "${file}"; then
    fail "File not found: ${file}"
  fi
    
  if ! sudo grep -qFx "${string}" "${file}"; then
    echo "${string}" | sudo tee -a "${file}" >/dev/null || fail
  fi
}

file::wait_until_available() {
  local file_path="$1"

  if [ ! -f "${file_path}" ]; then
    echo "File not found: '${file_path}'" >&2
    echo "Please connect the external media if the file resides on it" >&2
    echo "Waiting for the file to be available, press Control-C to interrupt" >&2
  fi

  while [ ! -f "${file_path}" ]; do
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

  local temp_file; temp_file="$(mktemp)" || softfail || return $?

  sed "/^\(#\|[[:graph:]]\+[[:blank:]]\+[[:graph:]]\+[[:blank:]]\+${fstype}[[:blank:]]\+.*[[:blank:][:punct:]]${skip}\([[:blank:][:punct:]]\|$\)\)/!s/^\([[:graph:]]\+[[:blank:]]\+[[:graph:]]\+[[:blank:]]\+${fstype}[[:blank:]]\+defaults\)\([^[:alnum:]]\|$\)/\1,${option}\2/g;" /etc/fstab >"${temp_file}" || softfail "Error applying sed to /etc/fstab" || return $?

  findmnt --verify --tab-file "${temp_file}" 2>&1 || softfail "fstab::add_mount_option -- failed to verify new fstab: ${temp_file}" || return $?

  sudo install --owner=root --group=root --mode=0664 --compare "${temp_file}" /etc/fstab || softfail "File install failed: from '${temp_file}' to '/etc/fstab'" || return $?
}
