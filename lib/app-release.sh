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
# REMOTE_HOST
# REMOTE_USER

app-release::init() {
  local appDir="${APP_DIR:-"${APP_NAME:?}"}"

  dir::make-if-not-exists "${appDir}" || softfail || return $?
  dir::make-if-not-exists "${appDir}/repo" || softfail || return $?
  dir::make-if-not-exists "${appDir}/shared" || softfail || return $?

  git --bare init "${appDir}/repo" || softfail || return $?
}

app-release::change-app-dir-group() {
  local appDir="${APP_DIR:-"${APP_NAME:?}"}"

  local groupName="$1"

  chgrp "${groupName}" "${appDir}" || softfail || return $?
}

app-release::get-absolute-app-dir() {
  local appDir="${APP_DIR:-"${APP_NAME:?}"}"

  local userHome; userHome="$(linux::get-user-home "${APP_USER}")" || softfail || return $?
  
  ( cd "${userHome}" >/dev/null 2>&1 && cd "${appDir}" >/dev/null 2>&1 && pwd ) || softfail "Unable to find application directory" || return $?
}

app-release::push-local-repo-to-remote() {
  local appDir="${APP_DIR:-"${APP_NAME:?}"}"
  local gitRemoteUrl="${REMOTE_USER:?}@${REMOTE_HOST:?}:${appDir}/repo"
  local remoteName="${REMOTE_USER}@${REMOTE_HOST}/${appDir}"

  if ! git config "remote.${remoteName}.url" >/dev/null; then
    git remote add "${remoteName}" "${gitRemoteUrl}" || softfail || return $?
  else
    git config "remote.${remoteName}.url" "${gitRemoteUrl}" || softfail || return $?
  fi

  git push "${remoteName}" master || softfail || return $?
}

app-release::make-with-group() {
  local groupName="$1"

  local dirMode; dirMode="$(dir::default-mode)" || softfail || return $?

  app-release::make "${dirMode}" "${APP_USER}" "${groupName}" || softfail || return $?
}

app-release::make() {
  local appDir="${APP_DIR:-"${APP_NAME:?}"}"

  local mode="${1:-}"
  local owner="${2:-}"
  local group="${3:-}"

  local currentDate; currentDate="$(date "+%Y%m%dT%H%M%SZ")" || softfail || return $?
  local releasesPath="${appDir}/releases"
  
  dir::make-if-not-exists "${releasesPath}" "${mode}" "${owner}" "${group}" || softfail || return $?

  local releaseDir; releaseDir="$(cd "${releasesPath}" >/dev/null 2>&1 && mktemp -d "${currentDate}-XXXX")" || softfail "Unable to make release directory" || return $?

  if [ -n "${mode}" ]; then
    chmod "${mode}" "${releasesPath}/${releaseDir}" || softfail || return $?
  else
    local dirMode; dirMode="$(dir::default-mode)" || softfail || return $?
    chmod "${dirMode}" "${releasesPath}/${releaseDir}" || softfail || return $?
  fi

  if [ -n "${owner}" ]; then
    chown "${owner}${group:+".${group}"}" "${releasesPath}/${releaseDir}" || softfail || return $?
  fi

  echo "${releaseDir}"
}

app-release::clone() {
  local appDir="${APP_DIR:-"${APP_NAME:?}"}"  
  local appReleasePath="${appDir}/releases/${APP_RELEASE:?}"
  
  if [ ! -d "${appReleasePath}/.git" ]; then
    git clone "${appDir}/repo" "${appReleasePath}" >/dev/null || softfail || return $?
  fi
}

# TODO: link to file? link to dir? Document magic happening here
app-release::link-shared-file() {
  local appDir="${APP_DIR:-"${APP_NAME:?}"}"
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
  if [ "${USER}" != "${APP_USER}" ]; then
    local userHome; userHome="$(linux::get-user-home "${APP_USER}")" || softfail || return $?
    ( cd "${userHome}" && app-release::link-as-current::perform "$@" ) || softfail || return $?
  else
    app-release::link-as-current::perform "$@" || softfail || return $?
  fi
}

app-release::link-as-current::perform() {
  local appDir="${APP_DIR:-"${APP_NAME:?}"}"

  local linkName="${appDir}/current"

  if [ -e "${linkName}" ] && [ ! -L "${linkName}" ]; then
    softfail "Unable to create a link to current release, file exists: ${linkName}"
    return $?
  fi

  ln --symbolic --force --no-dereference "releases/${APP_RELEASE:?}" "${appDir}/current" || softfail || return $?
}

app-release::cleanup() {
  local appDir="${APP_DIR:-"${APP_NAME:?}"}"

  local appReleasesCollectionPath="${appDir}/releases"

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
  local appDir="${APP_DIR:-"${APP_NAME:?}"}"
  # shellcheck disable=2034
  local REMOTE_DIR="${appDir}/releases/${APP_RELEASE:?}"
  "$@"
}

app-release::sync-to-remote() {
  local appDir="${APP_DIR:-"${APP_NAME:?}"}"
  local appReleasePath="${appDir}/releases/${APP_RELEASE:?}"

  local sourcePath="$1"
  local destPath="${2:-"$1"}"

  rsync::sync-to-remote "${sourcePath}" "${appReleasePath}/${destPath}" || softfail || return $?
}
