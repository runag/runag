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

git::install::apt() {
  if ! command -v git >/dev/null; then
    sudo DEBIAN_FRONTEND=noninteractive apt-get update || softfail || return $?
    sudo DEBIAN_FRONTEND=noninteractive apt-get -y install git || softfail || return $?
  fi
}

git::clone-local-mirror() {
  local source_path="$1"
  local dest_path="$2"

  local source_path_full; source_path_full="$(cd "${source_path}" >/dev/null 2>&1 && pwd)" || softfail || return $?

  if [ -d "${dest_path}" ]; then
    echo "Destination path already exists: ${dest_path}" >&2
    return
  fi

  git clone "${source_path}" "${dest_path}" || softfail || return $?
  git -C "${dest_path}" remote add local-mirror "${source_path_full}" || softfail || return $?

  local mirror_origin; mirror_origin="$(git -C "${source_path}" remote get-url origin)" || softfail || return $?
  git -C "${dest_path}" remote set-url origin "${mirror_origin}" || softfail || return $?
}

git::mirror() {
  local source_url="$1"
  local dest_path="$2"

  if [ -d "${dest_path}" ]; then
    echo "Destination path already exists: ${dest_path}" >&2
    return
  fi

  git clone --mirror "${source_url}" "${dest_path}" || softfail || return $?
}

git::place_up_to_date_clone() {
  local url="$1"; shift
  local dest="$1"; shift

  while [[ "$#" -gt 0 ]]; do
    case $1 in
    -b|--branch)
      local branch="$2"
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

  if [ -d "${dest}" ]; then
    local current_url; current_url="$(git -C "${dest}" config remote.origin.url)" || softfail || return $?

    if [ "${current_url}" != "${url}" ]; then
      local dest_full_path; dest_full_path="$(cd "${dest}" >/dev/null 2>&1 && pwd)" || softfail || return $?
      local dest_parent_dir; dest_parent_dir="$(dirname "${dest_full_path}")" || softfail || return $?
      local dest_dir_name; dest_dir_name="$(basename "${dest_full_path}")" || softfail || return $?
      local backup_path; backup_path="$(mktemp -u "${dest_parent_dir}/${dest_dir_name}-SOPKA-PREVIOUS-CLONE-XXXXXXXXXX")" || softfail || return $?

      mv "${dest_full_path}" "${backup_path}" || softfail || return $?

      git clone "${url}" "${dest}" || softfail "Unable to git clone ${url} to ${dest}" || return $?
    fi

    if [ -n "${branch:-}" ]; then
      git -C "${dest}" pull origin "${branch}" || softfail "Unable to git pull in ${dest}" || return $?
    else
      git -C "${dest}" pull || softfail "Unable to git pull in ${dest}" || return $?
    fi
  else
    git clone "${url}" "${dest}" || softfail "Unable to git clone ${url} to ${dest}" || return $?
  fi

  if [ -n "${branch:-}" ]; then
    git -C "${dest}" checkout "${branch}" || softfail "Unable to git checkout ${branch} in ${dest}" || return $?
  fi
}

git::configure_signing_key() {
  local key="$1"
  git config --global commit.gpgsign true || softfail || return $?
  git config --global user.signingkey "${key}" || softfail || return $?
}

# https://wiki.gnome.org/Projects/Libsecret
git::install_libsecret_credential_helper() {
  if [ ! -f /usr/share/doc/git/contrib/credential/libsecret/git-credential-libsecret ]; then
    (cd /usr/share/doc/git/contrib/credential/libsecret && sudo make) || softfail "Unable to compile libsecret" || return $?
  fi
}

git::use_libsecret_credential_helper() {
  git config --global credential.helper /usr/share/doc/git/contrib/credential/libsecret/git-credential-libsecret || softfail || return $?
}

git::gnome_keyring_credentials::exists() {
  local login="$1"
  local server="${2:-"github.com"}"

  secret-tool lookup server "${server}" user "${login}" protocol https xdg:schema org.gnome.keyring.NetworkPassword >/dev/null
}

git::gnome_keyring_credentials::save() {
  local password="$1"
  local login="$2"
  local server="${3:-"github.com"}"

  echo -n "${password}" | secret-tool store --label="Git: https://${server}/" server "${server}" user "${login}" protocol https xdg:schema org.gnome.keyring.NetworkPassword
  test "${PIPESTATUS[*]}" = "0 0" || softfail || return $?
}

git::install_git() {
  if [[ "${OSTYPE}" =~ ^linux ]]; then

    if ! command -v git >/dev/null; then
      if command -v apt-get >/dev/null; then
        apt::update || softfail || return $?
        apt::install git || softfail || return $?
      else
        fail "Unable to install git, apt-get not found"
      fi
    fi

  elif [[ "${OSTYPE}" =~ ^darwin ]]; then
    # on macos that will start git install process
    git --version >/dev/null || softfail || return $?
  fi
}

git::add_or_update_remote() {
  local remote_name="$1"
  local remote_url="$2"

  if ! git config "remote.${remote_name}.url" >/dev/null; then
    git remote add "${remote_name}" "${remote_url}" || softfail || return $?
  else
    git config "remote.${remote_name}.url" "${remote_url}" || softfail || return $?
  fi
}
