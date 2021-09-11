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

# ssh::add-host-to-known-hosts bitbucket.org || fail
# ssh::add-host-to-known-hosts github.com || fail

git::place-up-to-date-clone() {
  local url="$1"
  local dest="$2"
  local branch="${3:-}"

  if [ -d "${dest}" ]; then
    local currentUrl; currentUrl="$(git -C "${dest}" config remote.origin.url)" || fail

    if [ "${currentUrl}" != "${url}" ]; then
      local destFullPath; destFullPath="$(cd "${dest}" >/dev/null 2>&1 && pwd)" || fail
      local destParentDir; destParentDir="$(dirname "${destFullPath}")" || fail
      local destDirName; destDirName="$(basename "${destFullPath}")" || fail
      local packupPath; packupPath="$(mktemp -u "${destParentDir}/${destDirName}-SOPKA-PREVIOUS-CLONE-XXXXXXXXXX")" || fail
      mv "${destFullPath}" "${packupPath}" || fail
      git clone "${url}" "${dest}" || fail
    fi
    git -C "${dest}" pull || fail
  else
    git clone "${url}" "${dest}" || fail
  fi

  if [ -n "${branch:-}" ]; then
    git -C "${dest}" checkout "${branch}" || fail "Unable to checkout ${branch}"
  fi
}

git::configure-signingkey() {
  local key="$1"
  git config --global commit.gpgsign true || fail
  git config --global user.signingkey "${key}" || fail
}

# https://wiki.gnome.org/Projects/Libsecret
git::install-libsecret-credential-helper() {
  if [ ! -f /usr/share/doc/git/contrib/credential/libsecret/git-credential-libsecret ]; then
    (cd /usr/share/doc/git/contrib/credential/libsecret && sudo make) || fail "Unable to compile libsecret"
  fi
}

git::use-libsecret-credential-helper(){
  git config --global credential.helper /usr/share/doc/git/contrib/credential/libsecret/git-credential-libsecret || fail
}

git::gnome-keyring-credentials::exists() {
  local login="$1"
  local server="${2:-"github.com"}"

  secret-tool lookup server "${server}" user "${login}" protocol https xdg:schema org.gnome.keyring.NetworkPassword >/dev/null
}

git::gnome-keyring-credentials::save() {
  local password="$1"
  local login="$2"
  local server="${3:-"github.com"}"

  builtin printf "${password}" | secret-tool store --label="Git: https://${server}/" server "${server}" user "${login}" protocol https xdg:schema org.gnome.keyring.NetworkPassword
  test "${PIPESTATUS[*]}" = "0 0" || fail
}
