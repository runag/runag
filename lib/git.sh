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
      local packupPath; packupPath="$(mktemp -u "${destParentDir}/${destDirName}-SOPKA-PREVIOUS-CLONE-XXXXXXXX")" || fail
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

git::configure-user() {
  git config --global user.name "${GIT_USER_NAME}" || fail
  git config --global user.email "${GIT_USER_EMAIL}" || fail
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
git::install-libsecret-credential-helper() (
  if [ ! -f /usr/share/doc/git/contrib/credential/libsecret/git-credential-libsecret ]; then
    cd /usr/share/doc/git/contrib/credential/libsecret || fail
    sudo make || fail "Unable to compile libsecret"
  fi
)

git::add-credentials-to-gnome-keyring() {
  local bwItem="$1"

  # There is an indirection here. I assume that if there is a DBUS_SESSION_BUS_ADDRESS available then
  # the login keyring is also available and already initialized properly
  # I don't know yet how to check for login keyring specifically
  if [ -n "${DBUS_SESSION_BUS_ADDRESS:-}" ]; then
    if [ "${UPDATE_SECRETS:-}" = "true" ] || ! secret-tool lookup server github.com user "${GITHUB_LOGIN}" protocol https xdg:schema org.gnome.keyring.NetworkPassword >/dev/null; then
      bitwarden::unlock || fail

      # bitwarden-object: "? github personal access token"
      NODENV_VERSION=system bw get password "${bwItem} github personal access token" \
        | secret-tool store --label="Git: https://github.com/" server github.com user "${GITHUB_LOGIN}" protocol https xdg:schema org.gnome.keyring.NetworkPassword
      test "${PIPESTATUS[*]}" = "0 0" || fail "Unable to obtain and store github personal access token"
    fi
  else
    echo "Unable to store git credentials into the gnome keyring, DBUS not found" >&2
  fi
}
