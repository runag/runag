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

keys::mkdir() {
  if [ ! -d "${HOME}/.keys" ]; then
    mkdir -p -m 700 "${HOME}/.keys" || fail
  fi
}

# WARNING! It may leak key metadata if you have non-ubuntu system,
# sorry, but I dont have time to carefully think about mounting tmpfs right now

keys::check-tmpfs() {
  if [ -z "${XDG_RUNTIME_DIR}" ]; then
    fail "Unable to find XDG_RUNTIME_DIR"
  fi

  if ! df | grep "\s${XDG_RUNTIME_DIR}\$" | grep --quiet "^tmpfs\s"; then
    fail "Unable to find sutable tmpfs"
  fi
}

keys::maybe-create-or-update-checksum-file() {
  local current="$1"
  local new="$2"
  local title="$3"

  local action

  if [ ! -f "${current}" ]; then
    cat "${new}" || fail
    echo ""
    echo "${title}: Do you want to create the checksum file? (y/n)"

    IFS="" read -r action || fail

    if [ "${action}" = y ] || [ "${action}" = Y ]; then
      mv "${new}" "${current}" || fail
    else
      rm "${new}" || fail
    fi

    sync || fail
    return 0
  fi

  if diff --strip-trailing-cr "${current}" "${new}" >/dev/null 2>&1; then
    rm "${new}" || fail
    echo "${title}: Checksums are ok"
    return 0
  fi

  if command -v git >/dev/null; then
    git diff --ignore-cr-at-eol --color --unified=6 --no-index "${current}" "${new}" | tee
  else
    diff --strip-trailing-cr --context=6 --color "${current}" "${new}"
  fi

  echo ""
  echo "${title}: Do you want to update the checksum file? (y/n)"

  IFS="" read -r action || fail

  if [ "${action}" = y ] || [ "${action}" = Y ]; then
    mv "${new}" "${current}" || fail
    sync || fail
  else
    rm "${new}" || fail
  fi
}

keys::create-or-update-checksums()(
  keys::check-tmpfs || fail

  local current="checksum.txt"
  local new; new="$(mktemp -p "${XDG_RUNTIME_DIR}")" || fail
  local title="$1"

  cd "$1" || fail
  find -type f \( -not -name "${current}" \) -exec openssl dgst -sha3-256 {} \; | sort >"${new}"
  test "${PIPESTATUS[*]}" = "0 0" || fail

  keys::maybe-create-or-update-checksum-file "${current}" "${new}" "${title}" || fail
)

keys::verify-checksums()(
  keys::check-tmpfs || fail
  
  local current="checksum.txt"
  local new; new="$(mktemp -p "${XDG_RUNTIME_DIR}")" || fail
  local title="$1"

  cd "$1" || fail

  if [ ! -f "${current}" ]; then
    fail "${title}: Unable to find checksum file ${current}"
  fi

  find -type f \( -not -name "${current}" \) -exec openssl dgst -sha3-256 {} \; | sort >"${new}"
  test "${PIPESTATUS[*]}" = "0 0" || fail

  if diff --strip-trailing-cr "${current}" "${new}" >/dev/null 2>&1; then
    rm "${new}" || fail
    echo "${title}: Checksums are ok"
    return 0
  fi

  if command -v git >/dev/null; then
    git diff --ignore-cr-at-eol --color --unified=6 --no-index "${current}" "${new}" | tee
  else
    diff --strip-trailing-cr --context=6 --color "${current}" "${new}"
  fi

  rm "${new}" || fail
  fail "${title}: Checksums are different!"
)

keys::create-update-or-verify-key-checksums() {
  local media="$1"
  local dir

  for dir in "${media}"/*keys* ; do
    if [ -d "$dir" ]; then
      keys::create-or-update-checksums "$dir" || fail
    fi
  done

  for dir in "${media}"/copies/*/* ; do
    if [ -d "$dir" ]; then
      keys::verify-checksums "$dir" || fail
    fi
  done
}

keys::for-all-mounted-media() {
  local dir

  for dir in /media/"${USER}"/KEYS-* ; do
    if [ -d "$dir" ]; then
      "$1" "$dir" || fail
    fi
  done
}

keys::maintain-checksums() {
  keys::for-all-mounted-media keys::create-update-or-verify-key-checksums || fail
}

keys::make-backup-copies() {
  local src="$1"
  local media="$2"
  local dest="copies/${src}/${CURRENT_TIMESTAMP}"
  
  if [ -d "${dest}" ]; then
    fail "${media}/${dest}: copy already exists"
  fi

  mkdir -p "copies/${src}" || fail

  cp -R "${src}" "${dest}" || fail
  
  sync || fail

  echo "${media}/${dest}: copy was made"
}

keys::make-backup-copies-for-all-keys() (
  local media="$1"
  local dir

  cd "${media}" || fail

  for dir in *keys* ; do
    if [ -d "${dir}" ]; then
      keys::make-backup-copies "${dir}" "${media}" || fail
    fi
  done
)

keys::make-backups() {
  local CURRENT_TIMESTAMP; CURRENT_TIMESTAMP="$(date --utc +"%Y%m%dT%H%M%SZ")" || fail
  CURRENT_TIMESTAMP="${CURRENT_TIMESTAMP}" keys::for-all-mounted-media keys::make-backup-copies-for-all-keys || fail
}

keys::ensure-key-is-available() {
  local keyPath="$1"
  if [ ! -f "${keyPath}" ]; then
    echo "File not found: '${keyPath}'. Please connect external media if necessary and press ENTER" >&2
    read -s || fail
  fi
  if [ ! -f "${keyPath}" ]; then
    fail "File still not found: ${keyPath}"
  fi
}

keys::install-gpg-key() {
  local key="$1"
  local sourcePath="$2"

  if ! gpg --list-keys "${key}" >/dev/null 2>&1; then
    keys::ensure-key-is-available "${sourcePath}" || fail
    gpg --import "${sourcePath}" || fail
    echo "${key}:6:" | gpg --import-ownertrust || fail
  fi
}

keys::install-decrypted-file() {
  local sourcePath="$1"
  local destPath="$2"
  local destMode="${3:-}"

  if [ ! -f "${destPath}" ]; then
    keys::ensure-key-is-available "${sourcePath}" || fail
    gpg --decrypt "${sourcePath}" | file::write "${destPath}" "${destMode}"
    test "${PIPESTATUS[*]}" = "0 0" || fail
  fi
}
