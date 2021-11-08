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

# APP_DIR
# APP_RELEASE

app-release::init() {
  local appDir="${APP_DIR:?}"

  dir::make-if-not-exists "${appDir}" || softfail || return $?
  dir::make-if-not-exists "${appDir}/repo" || softfail || return $?
  dir::make-if-not-exists "${appDir}/shared" || softfail || return $?

  git --bare init "${appDir}/repo" || softfail || return $?
}

app-release::push-local-repo-to-remote() {
  local gitRemoteUrl="${REMOTE_USER:?}@${REMOTE_HOST:?}:${APP_DIR:?}/repo"
  local remoteName="${REMOTE_USER}@${REMOTE_HOST}/${APP_DIR}"

  if ! git config "remote.${remoteName}.url" >/dev/null; then
    git remote add "${remoteName}" "${gitRemoteUrl}" || softfail || return $?
  else
    git config "remote.${remoteName}.url" "${gitRemoteUrl}" || softfail || return $?
  fi

  git push "${remoteName}" master || softfail || return $?
}

app-release::make() {
  local appDir="${APP_DIR:?}"

  local mode="${1:-}"
  local owner="${2:-}"
  local group="${3:-}"

  local currentDate; currentDate="$(date "+%Y%m%dT%H%M%SZ")" || softfail || return $?
  local releasesPath="${appDir}/releases"
  
  dir::make-if-not-exists "${releasesPath}" "${mode}" "${owner}" "${group}" || softfail || return $?

  local releaseDir; releaseDir="$(cd "${releasesPath}" >/dev/null 2>&1 && mktemp -d "${currentDate}-XXXX")" || softfail "Unable to make release directory" || return $?

  if [ -n "${mode}" ]; then
    chmod "${mode}" "${releasesPath}/${releaseDir}" || softfail || return $?
  fi

  if [ -n "${owner}" ]; then
    chown "${owner}${group:+".${group}"}" "${releasesPath}/${releaseDir}" || softfail || return $?
  fi

  echo "${releaseDir}"
}

app-release::clone() {
  local appDir="${APP_DIR:?}"
  local appReleasePath="${appDir}/releases/${APP_RELEASE:?}"
  
  if [ ! -d "${appReleasePath}/.git" ]; then
    git clone "${appDir}/repo" "${appReleasePath}" >/dev/null || softfail || return $?
  fi
}

# TODO: link to file? link to dir? Document magic happening here
app-release::link-shared-file() {
  local appDir="${APP_DIR:?}"
  local appReleasePath="${appDir}/releases/${APP_RELEASE:?}"

  local linkPath="${appReleasePath}/$1"
  local target="${2:-"${appDir}/shared/$1"}"

  if [ ! -e "${target}" ]; then
    mkdir -p "${target}" || softfail || return $?
  fi

  local linkDirPath; linkDirPath="$(dirname "${linkPath}")" || softfail || return $?

  if [ ! -e "${linkDirPath}" ]; then
    mkdir -p "${linkDirPath}" || softfail || return $?
  fi

  if [ -e "${linkPath}" ]; then
    local backupName; backupName="$(mktemp -d "${appReleasePath}/.sopka-app-release-link-backup-XXXXXXXXXX")" || softfail || return $?
    mv "${linkPath}" "${backupName}" || softfail || return $?
  fi

  local targetAbsolutePath; targetAbsolutePath="$(fs::get-absolute-path "${target}")" || softfail || return $?

  ln --symbolic "${targetAbsolutePath}" "${linkPath}" || softfail || return $?
}

app-release::link-as-current() {
  local appDir="${APP_DIR:?}"

  local linkName="${appDir}/current"

  if [ -e "${linkName}" ] && [ ! -L "${linkName}" ]; then
    softfail "Unable to create a link to current release, file exists: ${linkName}"
    return $?
  fi

  ln --symbolic --force --no-dereference "releases/${APP_RELEASE:?}" "${appDir}/current" || softfail || return $?
}

app-release::cleanup() {
  local appReleasesCollectionPath="${APP_DIR:?}/releases"

  local keepAmount="${1:-10}"

  local release
  local removeThisRelease

  for release in "${appReleasesCollectionPath:?}"/*; do
    echo "${release}"
  done | sort | head "--lines=-${keepAmount}" | \
  while IFS="" read -r removeThisRelease; do
    echo "Removing ${removeThisRelease}..."
    rm -rf "${removeThisRelease:?}" || softfail || return $?
  done

  if [[ "${PIPESTATUS[*]}" =~ [^0[:space:]] ]]; then
    softfail || return $?
  fi
}

app-release::with-release-remote-dir() {
  # shellcheck disable=2034
  local REMOTE_DIR="${APP_DIR:?}/releases/${APP_RELEASE:?}"
  "$@"
}

app-release::sync-to-remote() {
  local appReleasePath="${APP_DIR:?}/releases/${APP_RELEASE:?}"

  local sourcePath="$1"
  local destPath="${2:-"$1"}"

  rsync::sync-to-remote "${sourcePath}" "${appReleasePath}/${destPath}" || fail
}
