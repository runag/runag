#!/usr/bin/env bash

#  Copyright 2012-2021 Stanislav Senotrusov <stan@senotrusov.com>
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

path::convert-msys-to-windows() {
  echo "$1" | sed "s/^\\/\\([[:alpha:]]\\)\\//\\1:\\//" | sed "s/\\//\\\\/g"
  test "${PIPESTATUS[*]}" = "0 0 0" || fail
}  

dir::make-if-not-exists() {
  local dirPath="$1"
  local mode="${2:-}"
  local owner="${3:-}"
  local group="${4:-}"

  if mkdir ${mode:+-m "${mode}"} "${dirPath}" 2>/dev/null; then
    if [ -n "${owner}" ]; then
      chown "${owner}${group:+".${group}"}" "${dirPath}" || fail
    fi
  else
    test -d "${dirPath}" || fail "Unable to create directory, maybe there is a file here already: ${dirPath}"
  fi
}

dir::make-if-not-exists-and-set-permissions() {
  local dirPath="$1"
  local mode="${2:-}"
  local owner="${3:-}"
  local group="${4:-}"

  if ! mkdir ${mode:+-m "${mode}"} "${dirPath}" 2>/dev/null; then
    test -d "${dirPath}" || fail "Unable to create directory, maybe there is a file here already: ${dirPath}"
    chmod "${mode}" "${dirPath}" || fail
  fi

  if [ -n "${owner}" ]; then
    chown "${owner}${group:+".${group}"}" "${dirPath}" || fail
  fi
}

dir::sudo-make-if-not-exists() {
  local dirPath="$1"
  local mode="${2:-}"
  local owner="${3:-}"
  local group="${4:-}"

  if sudo mkdir ${mode:+-m "${mode}"} "${dirPath}" 2>/dev/null; then
    if [ -n "${owner}" ]; then
      sudo chown "${owner}${group:+".${group}"}" "${dirPath}" || fail
    fi
  else
    test -d "${dirPath}" || fail "Unable to create directory, maybe there is a file here already: ${dirPath}"
  fi
}

dir::sudo-make-if-not-exists-and-set-permissions() {
  local dirPath="$1"
  local mode="${2:-}"
  local owner="${3:-}"
  local group="${4:-}"

  if ! sudo mkdir ${mode:+-m "${mode}"} "${dirPath}" 2>/dev/null; then
    test -d "${dirPath}" || fail "Unable to create directory, maybe there is a file here already: ${dirPath}"
    sudo chmod "${mode}" "${dirPath}" || fail
  fi

  if [ -n "${owner}" ]; then
    sudo chown "${owner}${group:+".${group}"}" "${dirPath}" || fail
  fi
}

dir::remove-if-exists-and-empty() {
  local dirPath="$1"
  rmdir "${dirPath}" 2>/dev/null || true
}

dir::default-mode() {
  local umaskValue; umaskValue="$(umask)" || softfail || return $?
  printf "%o" "$(( 0777 ^ "${umaskValue}" ))" || softfail || return $?
}

dir::default-mode-with-remote-umask() {
  printf "%o" "$(( 0777 ^ "0${REMOTE_UMASK}" ))" || softfail || return $?
}

file::sudo-write() {
  local dest="$1"
  local mode="${2:-}"
  local owner="${3:-}"
  local group="${4:-}"

  if [ -n "${mode}" ] || [ -n "${owner}" ] || [ -n "${group}" ]; then
    # I want to create a file with the right mode right away
    # the use of "install" command performs that, at least on linux and macos
    # it creates a file with the mode 600, which is good, and then it changes the mode to the one provided in the argument
    # it's probably better to make it different, like calculate umask and then touch, but I don't have time to think about that right now
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
    # it's probably better to make it different, like calculate umask and then touch, but I don't have time to think about that right now
    install -m "${mode}" /dev/null "${dest}" || fail
  fi

  cat >"${dest}" || fail
}

file::append-line-unless-present() {
  local string="$1"
  local file="$2"

  if ! test -f "${file}"; then
    fail "File not found: ${file}"
  fi

  if ! grep -qFx "${string}" "${file}"; then
    echo "${string}" | tee -a "${file}" >/dev/null || fail
  fi
}

file::sudo-append-line-unless-present() {
  local string="$1"
  local file="$2"

  if ! sudo test -f "${file}"; then
    fail "File not found: ${file}"
  fi
    
  if ! sudo grep -qFx "${string}" "${file}"; then
    echo "${string}" | sudo tee -a "${file}" >/dev/null || fail
  fi
}

file::wait-until-available() {
  local filePath="$1"

  if [ ! -f "${filePath}" ]; then
    echo "File not found: '${filePath}'" >&2
    echo "Please connect the external media if the file resides on it" >&2
    echo "Waiting for the file to be available, press Control-C to interrupt" >&2
  fi

  while [ ! -f "${filePath}" ]; do
    sleep 0.1
  done
}

mount::wait-until-available() {
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
  local selfDir
  selfDir="$(dirname "$1")" || softfail "Unable to get dirname of $1" || return $?

  . "${selfDir}/$2" || softfail "Unable to load: ${selfDir}/$2" || return $?
}

fs::recursive-source() {
  local selfDir filePath
  
  selfDir="$(dirname "$1")" || softfail "Unable to get dirname of $1" || return $?

  while IFS= read -r -d '' filePath; do
    . "${filePath}" || softfail "Unable to load: ${filePath}" || return $?
  done < <(find "${selfDir}/$2" -type f -name '*.sh' -print0)
}

fs::get-absolute-path() {
  local relativePath="$1"
  
  # get basename
  local pathBasename; pathBasename="$(basename "${relativePath}")" \
    || softfail "Sopka: Unable to get a basename of '${relativePath}' ($?)" || return $?

  # get dirname that yet may result to relative path
  local unresolvedDir; unresolvedDir="$(dirname "${relativePath}")" \
    || softfail "Sopka: Unable to get a dirname of '${relativePath}'" || return $?

  # get absolute path
  local resolvedDir; resolvedDir="$(cd "${unresolvedDir}" >/dev/null 2>&1 && pwd)" \
    || softfail "Sopka: Unable to determine absolute path for '${unresolvedDir}'" || return $?

  echo "${resolvedDir}/${pathBasename}"
}
