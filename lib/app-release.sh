#!/usr/bin/env bash

#  Copyright 2012-2024 Rùnag project contributors
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

app_release::init() {
  local app_dir="${APP_DIR:-"${APP_NAME:?}"}"

  dir::should_exists --mode 0700 "${app_dir}" || softfail || return $?
  dir::should_exists --mode 0700 "${app_dir}/repo" || softfail || return $?
  dir::should_exists --mode 0700 "${app_dir}/shared" || softfail || return $?

  git --bare init "${app_dir}/repo" || softfail || return $?
}

app_release::change_app_dir_group() {
  local app_dir="${APP_DIR:-"${APP_NAME:?}"}"

  local group_name="$1"

  chgrp "${group_name}" "${app_dir}" || softfail || return $?
}

app_release::get_absolute_app_dir() {
  local app_dir="${APP_DIR:-"${APP_NAME:?}"}"

  local user_home; user_home="$(linux::get_home_dir "${APP_USER}")" || softfail || return $?
  
  ( cd "${user_home}" >/dev/null 2>&1 && cd "${app_dir}" >/dev/null 2>&1 && pwd ) || softfail "Unable to find application directory" || return $?
}

app_release::push_local_repo_to_remote() {
  local app_dir="${APP_DIR:-"${APP_NAME:?}"}"
  local remote_name="${REMOTE_USER}@${REMOTE_HOST}/${app_dir}"
  local git_remote_url="${REMOTE_USER:?}@${REMOTE_HOST:?}:${app_dir}/repo"

  git::add_or_update_remote "${remote_name}" "${git_remote_url}" || softfail || return $?

  git push "${remote_name}" main || softfail || return $?
}

app_release::pull_remote_to_local_repo() {
  local app_dir="${APP_DIR:-"${APP_NAME:?}"}"
  local remote_name="${REMOTE_USER}@${REMOTE_HOST}/${app_dir}"
  local git_remote_url="${REMOTE_USER:?}@${REMOTE_HOST:?}:${app_dir}/repo"

  git::add_or_update_remote "${remote_name}" "${git_remote_url}" || softfail || return $?

  git pull "${remote_name}" main || softfail || return $?
}

app_release::make_with_group() {
  local group_name="$1"

  local dir_mode; dir_mode="$(dir::default_mode)" || softfail || return $?

  app_release::make "${dir_mode}" "${APP_USER}" "${group_name}" || softfail || return $?
}

app_release::make() {
  local app_dir="${APP_DIR:-"${APP_NAME:?}"}"

  local mode="${1:-}"
  local owner="${2:-}"
  local group="${3:-}"

  local current_date; current_date="$(date --utc "+%Y%m%dT%H%M%SZ")" || softfail || return $?
  local releases_path="${app_dir}/releases"
  
  # TODO: check how --arguments pass through
  dir::should_exists --mode "${mode}" --owner "${owner}" --group "${group}" "${releases_path}" || softfail || return $?

  local release_dir; release_dir="$(cd "${releases_path}" >/dev/null 2>&1 && mktemp -d "${current_date}-XXXX")" || softfail "Unable to make release directory" || return $?

  if [ -n "${mode}" ]; then
    chmod "${mode}" "${releases_path}/${release_dir}" || softfail || return $?
  else
    local dir_mode; dir_mode="$(dir::default_mode)" || softfail || return $?
    chmod "${dir_mode}" "${releases_path}/${release_dir}" || softfail || return $?
  fi

  if [ -n "${owner}" ]; then
    chown "${owner}${group:+".${group}"}" "${releases_path}/${release_dir}" || softfail || return $?
  fi

  echo "${release_dir}"
}

app_release::clone() {
  local app_dir="${APP_DIR:-"${APP_NAME:?}"}"  
  local app_release_path="${app_dir}/releases/${APP_RELEASE:?}"
  
  if [ ! -d "${app_release_path}/.git" ]; then
    git clone "${app_dir}/repo" "${app_release_path}" >/dev/null || softfail || return $?
  fi
}

# TODO: link to file? link to dir? Document what kind of magic is happening here
app_release::link_shared_file() {
  local app_dir="${APP_DIR:-"${APP_NAME:?}"}"
  local app_release_path="${app_dir}/releases/${APP_RELEASE:?}"

  local link_path="${app_release_path}/$1"
  local target="${2:-"${app_dir}/shared/$1"}"

  if [ ! -e "${target}" ]; then
    mkdir -p "${target}" || softfail || return $?
  fi

  local link_dir_path; link_dir_path="$(dirname "${link_path}")" || softfail || return $?

  if [ ! -e "${link_dir_path}" ]; then
    mkdir -p "${link_dir_path}" || softfail || return $?
  fi

  if [ -e "${link_path}" ]; then
    local backup_name; backup_name="$(mktemp -d "${app_release_path}/.app-release-link-backup-XXXXXXXXXX")" || softfail || return $?
    mv "${link_path}" "${backup_name}" || softfail || return $?
  fi

  local target_absolute_path; target_absolute_path="$(fs::get_absolute_path "${target}")" || softfail || return $?

  ln --symbolic "${target_absolute_path}" "${link_path}" || softfail || return $?
}

app_release::link_as_current() {
  if [ "${USER}" != "${APP_USER}" ]; then
    local user_home; user_home="$(linux::get_home_dir "${APP_USER}")" || softfail || return $?
    ( cd "${user_home}" && app_release::link_as_current::perform "$@" ) || softfail || return $?
  else
    app_release::link_as_current::perform "$@" || softfail || return $?
  fi
}

app_release::link_as_current::perform() {
  local app_dir="${APP_DIR:-"${APP_NAME:?}"}"

  fs::update_symlink "releases/${APP_RELEASE:?}" "${app_dir}/current" || softfail || return $?
}

app_release::cleanup() {
  local app_dir="${APP_DIR:-"${APP_NAME:?}"}"

  local app_releases_collection_path="${app_dir}/releases"

  local keep_amount="${1:-10}"

  local release
  local remove_this_release

  for release in "${app_releases_collection_path:?}"/*; do
    if [ -d "${release}" ]; then
      echo "${release}"
    fi
  done | sort | head "--lines=-${keep_amount}" | \
  while IFS="" read -r remove_this_release; do
    echo "Removing ${remove_this_release}..."
    rm -rf "${remove_this_release:?}" || softfail || return $?
  done

  if [[ "${PIPESTATUS[*]}" =~ [^0[:space:]] ]]; then
    softfail || return $?
  fi
}

app_release::with_release_remote_dir() {
  local app_dir="${APP_DIR:-"${APP_NAME:?}"}"
  # shellcheck disable=2034
  local REMOTE_DIR="${app_dir}/releases/${APP_RELEASE:?}"
  "$@"
}

app_release::sync_to_remote() {
  local app_dir="${APP_DIR:-"${APP_NAME:?}"}"
  local app_release_path="${app_dir}/releases/${APP_RELEASE:?}"

  local source_path="$1"
  local dest_path="${2:-"$1"}"

  rsync::sync --to-remote "${source_path}" "${app_release_path}/${dest_path}" || softfail || return $?
}
