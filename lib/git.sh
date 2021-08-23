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

git::install-with-libsecret-credential-helper() {
  apt::install git || fail
  apt::install-gnome-keyring-and-libsecret || fail
  git::install-libsecret-credential-helper || fail
  git::use-libsecret-credential-helper || fail
}

git::use-libsecret-credential-helper(){
  git config --global credential.helper /usr/share/doc/git/contrib/credential/libsecret/git-credential-libsecret || fail
}

# https://wiki.gnome.org/Projects/Libsecret
git::install-libsecret-credential-helper() {
  if [ ! -f /usr/share/doc/git/contrib/credential/libsecret/git-credential-libsecret ]; then
    (cd /usr/share/doc/git/contrib/credential/libsecret && sudo make) || fail "Unable to compile libsecret"
  fi
}

git::add-credentials-to-gnome-keyring() {
  local bitwardenId="$1"
  local login="$2"
  local server="${3:-"github.com"}"

  # I assume that if there is a DBUS_SESSION_BUS_ADDRESS available then the login keyring
  # is also available and already initialized properly.
  # I don't know yet how to specifically check for login keyring
  if [ -z "${DBUS_SESSION_BUS_ADDRESS:-}" ]; then
    fail "Unable to store git credentials into the gnome keyring, DBUS not found"
  fi

  if secret-tool lookup server "${server}" user "${login}" protocol https xdg:schema org.gnome.keyring.NetworkPassword >/dev/null && [ "${SOPKA_UPDATE_SECRETS:-}" != "true" ]; then
    return 0
  fi

  bitwarden::unlock || fail

  # bitwarden-object: "?"
  NODENV_VERSION=system bw get password "${bitwardenId}" \
    | secret-tool store --label="Git: https://${server}/" server "${server}" user "${login}" protocol https xdg:schema org.gnome.keyring.NetworkPassword

  test "${PIPESTATUS[*]}" = "0 0" || fail "Unable to obtain or store git credentials"
}
