#!/usr/bin/env bash

#  Copyright 2012-2019 Stanislav Senotrusov <stan@senotrusov.com>
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

git::configure() {
  git config --global user.name "${GIT_USER_NAME}" || fail
  git config --global user.email "${GIT_USER_EMAIL}" || fail
  git config --global core.autocrlf input || fail
}

git::cd-to-temp-clone() {
  local url="$1"
  local branch="${2:-}"

  local tempDir; tempDir="$(mktemp -d)" || fail "Unable to create temp dir"

  git::clone-or-pull "${url}" "${tempDir}" "${branch}" || fail

  cd "${tempDir}" || fail

  SOPKA_SRC_GIT_TEMP_CLONE_DIR="${tempDir}" || fail
}

git::remove-temp-clone() {
  rm -rf "${SOPKA_SRC_GIT_TEMP_CLONE_DIR}" || fail
}

git::clone-or-pull() {
  local url="$1"
  local dest="$2"
  local branch="${3:-}"

  if [ -d "$dest" ]; then
    git -C "$dest" config remote.origin.url "${url}" || fail
    git -C "$dest" pull || fail
  else
    git clone "$url" "$dest" || fail
  fi

  if [ -n "${branch:-}" ]; then
    git -C "$dest" checkout "${branch}" || fail "Unable to checkout ${branch}"
  fi
}
