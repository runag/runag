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

git::install_profile_from_pass() {
  local pass_path="$1"
  
  if pass::exists "${pass_path}/user-name"; then
    local user_name; user_name="$(pass::use "${pass_path}/user-name")" || softfail || return $?

    git config "${@:2}" user.name "${user_name}" || softfail || return $?
  fi

  if pass::exists "${pass_path}/user-email"; then
    local user_email; user_email="$(pass::use "${pass_path}/user-email")" || softfail || return $?

    git config "${@:2}" user.email "${user_email}" || softfail || return $?
  fi

  if pass::exists "${pass_path}/signing-key"; then
    local signing_key; signing_key="$(pass::use "${pass_path}/signing-key")" || softfail || return $?

    git config "${@:2}" commit.gpgsign true || softfail || return $?
    git config "${@:2}" user.signingkey "${signing_key}" || softfail || return $?
  fi
}

# git::clone_local_mirror() {
#   local source_path="$1"
#   local dest_path="$2"
#
#   local source_path_full; source_path_full="$(cd "${source_path}" >/dev/null 2>&1 && pwd)" || softfail || return $?
#
#   if [ -d "${dest_path}" ]; then
#     softfail "Destination path already exists: ${dest_path}" || return $?
#   fi
#
#   git clone "${source_path}" "${dest_path}" || softfail || return $?
#   git -C "${dest_path}" remote add local-mirror "${source_path_full}" || softfail || return $?
#
#   local mirror_origin; mirror_origin="$(git -C "${source_path}" remote get-url origin)" || softfail || return $?
#   git -C "${dest_path}" remote set-url origin "${mirror_origin}" || softfail || return $?
# }

git::create_or_update_mirror() {
  local source_url="$1"
  local dest_path="$2"

  if [ -d "${dest_path}" ]; then
    git -C "${dest_path}" remote update || softfail || return $?
  else
    git clone --mirror "${source_url}" "${dest_path}" || softfail || return $?
  fi
}

git::place_up_to_date_clone() {
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

  local url="$1"
  local dest="$2"

  if [ -d "${dest}" ]; then
    local current_url; current_url="$(git -C "${dest}" config remote.origin.url)" || softfail || return $?

    if [ "${current_url}" != "${url}" ]; then
      local dest_full_path; dest_full_path="$(cd "${dest}" >/dev/null 2>&1 && pwd)" || softfail || return $?
      local dest_parent_dir; dest_parent_dir="$(dirname "${dest_full_path}")" || softfail || return $?
      local dest_dir_name; dest_dir_name="$(basename "${dest_full_path}")" || softfail || return $?
      local backup_path; backup_path="$(mktemp -u "${dest_parent_dir}/${dest_dir_name}-RUNAG-PREVIOUS-CLONE-XXXXXXXXXX")" || softfail || return $?

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
  local server="$1"
  local login="$2"

  secret-tool lookup server "${server}" user "${login}" protocol https xdg:schema org.gnome.keyring.NetworkPassword >/dev/null
}

git::gnome_keyring_credentials() {
  local server="$1"
  local login="$2"
  local password="$3"

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

git::get_remote_url_without_username() {
  local remote_name="${1:-"origin"}"
  git remote get-url "${remote_name}" | sed 's/^https:\/\/[[:alnum:]_]\+@/https:\/\//'
  test "${PIPESTATUS[*]}" = "0 0" || softfail || return $?
}

git::disable_nested_repositories() {
  git::disable_nested_repositories::item d .git || softfail || return $?
  git::disable_nested_repositories::item f .gitignore || softfail || return $?
  git::disable_nested_repositories::item f .gitattributes || softfail || return $?
}

git::enable_nested_repositories() {
  git::enable_nested_repositories::item d .git || softfail || return $?
  git::enable_nested_repositories::item f .gitignore || softfail || return $?
  git::enable_nested_repositories::item f .gitattributes || softfail || return $?
}

# shellcheck disable=2016
git::disable_nested_repositories::item() {
  find . -type "$1" -name "$2" ! -path "./$2" -print0 | xargs -0 -n1 -r bash -c 'dir_name="$(dirname "$1")" && echo "Disabling $1" && mv "$1" "$dir_name/'"$2"'-disabled" || echo "Unable to rename $1"' rename-script || softfail || return $?
}

# shellcheck disable=2016
git::enable_nested_repositories::item() {
  find . -type "$1" -name "$2"-disabled -print0 | xargs -0 -n1 -r bash -c 'dir_name="$(dirname "$1")" && echo "Enabling $1" && mv "$1" "$dir_name/'"$2"'" || echo "Unable to rename $1"' rename-script || softfail || return $?
}
