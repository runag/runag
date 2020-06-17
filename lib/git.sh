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

# deploy-lib::ssh::add-host-known-hosts bitbucket.org || fail
# deploy-lib::ssh::add-host-known-hosts github.com || fail

deploy-lib::git::configure() {
  git config --global user.name "${GIT_USER_NAME}" || fail
  git config --global user.email "${GIT_USER_EMAIL}" || fail
  git config --global core.autocrlf input || fail
}

deploy-lib::git::cd-to-temp-clone() {
  local repoUrl="$1"
  local branch="${2:-}"

  local localCloneDir; localCloneDir="$(basename "$repoUrl")" || fail

  local tempDir; tempDir="$(mktemp --dry-run --tmpdir="${HOME}" "${localCloneDir}-XXXXXX")" || fail "Unable to create temp file"

  deploy-lib::git::make-repository-clone-available "${repoUrl}" "${tempDir}" "${branch}" || fail

  cd "${tempDir}" || fail

  export DEPLOY_LIB_GIT_TEMP_CLONE_DIR="${tempDir}" || fail
}

deploy-lib::git::remove-temp-clone() {
  rm -rf "${DEPLOY_LIB_GIT_TEMP_CLONE_DIR}" || fail
}

deploy-lib::git::make-repository-clone-available() {
  local repoUrl="$1"
  local localCloneDir; localCloneDir="${2:-$(basename "$repoUrl")}" || fail
  local branch="${3:-"master"}"

  if [ ! -d "${localCloneDir}" ]; then
    git clone "${repoUrl}" "${localCloneDir}" || fail "Unable to clone ${repoUrl} into ${localCloneDir}"
  else
    local existingRepoUrl; existingRepoUrl="$(cd "${localCloneDir}" && git config --get remote.origin.url)" || fail "Unable to get existingRepoUrl"

    if [ "${existingRepoUrl}" = "${repoUrl}" ]; then
      (cd "${localCloneDir}" && git pull) || fail "Unable to pull from ${repoUrl}"
    else
      if (cd "${localCloneDir}" 2>/dev/null && git diff-index --quiet HEAD --); then
        rm -rf "${localCloneDir}" || fail "Unable to delete repository ${localCloneDir}"
        git clone "${repoUrl}" "${localCloneDir}" || fail "Unable to clone ${repoUrl} into ${localCloneDir}"
      else
        fail "Local clone ${localCloneDir} is cloned from ${existingRepoUrl} and there are local changes. It is expected to be a clone of ${repoUrl}."
      fi
    fi
  fi

  if [ -n "${branch}" ]; then
    (cd "${localCloneDir}" && git checkout "${branch}") || fail "Unable to checkout ${branch}"
  fi
}
