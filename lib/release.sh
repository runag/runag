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

release::deploy() {
  local source_path
  local dest_path
  local load_local_runagfile
  local ssh_call
  local ssh_call_prefix

  while [ "$#" -gt 0 ]; do
    case $1 in
      -s|--source)
        source_path="$2"
        shift; shift
        ;;
      -d|--dest)
        dest_path="$2"
        shift; shift
        ;;
      -l|--load-local-runagfile)
        load_local_runagfile=true
        shift
        ;;
      -c|--ssh-call)
        ssh_call=true
        ssh_call_prefix="ssh::call"
        shift
        ;;
      -w|--ssh-call-with)
        ssh_call=true
        ssh_call_prefix="$2"
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

  if [ -z "${dest_path:-}" ]; then
    dest_path="$(basename "${source_path}")" || softfail || return $?
  fi

  ${ssh_call:+"${ssh_call_prefix}"} release::init --dest "${dest_path}" || softfail || return $?

  release::push --source "${source_path}" --dest "${dest_path}" || softfail || return $?

  ${ssh_call:+"${ssh_call_prefix}"} release::create ${load_local_runagfile:+"--load-local-runagfile"} --dest "${dest_path}" || softfail || return $?
}

release::init() {
  local dest_path

  while [ "$#" -gt 0 ]; do
    case $1 in
      -d|--dest)
        dest_path="$2"
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

  dir::should_exists --mode 0700 "${dest_path}" || softfail || return $?
  dir::should_exists --mode 0700 "${dest_path}/releases" || softfail || return $?
  dir::should_exists --mode 0700 "${dest_path}/repo" || softfail || return $?
  dir::should_exists --mode 0700 "${dest_path}/shared" || softfail || return $?

  git init --quiet --bare "${dest_path}/repo" || softfail || return $?
  
  ( cd "${dest_path}/repo" && git symbolic-ref HEAD refs/heads/main ) || softfail || return $?
}

release::push() (
  local source_path
  local dest_path

  while [ "$#" -gt 0 ]; do
    case $1 in
      -s|--source)
        source_path="$2"
        shift; shift
        ;;
      -d|--dest)
        dest_path="$2"
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

  cd "${source_path}" || softfail || return $?

  local git_status_length; git_status_length="$(git status --porcelain=v1 | wc --bytes; test "${PIPESTATUS[*]}" = "0 0")" || softfail "Unable to obtain git status" || return $?

  if [ "${git_status_length}" != 0 ]; then
    log::warning "There are uncommited changes in ${PWD}"
  fi

  local remote_name="${REMOTE_USER}@${REMOTE_HOST}/${dest_path}"
  local git_remote_url="${REMOTE_USER:?}@${REMOTE_HOST:?}:${dest_path}/repo"

  git::add_or_update_remote "${remote_name}" "${git_remote_url}" || softfail || return $?

  if git ls-remote --exit-code --heads "${remote_name}" main >/dev/null; then
    git pull --quiet "${remote_name}" main || fail
  fi

  # if I use --set-upstream here, then on every deploy main.remote will be set to deploy remote
  # but maybe I need that somehow for the first deploy?
  # TODO: check that later
  git push --quiet "${remote_name}" main || fail
)

release::create() (
  local dest_path
  local load_local_runagfile

  while [ "$#" -gt 0 ]; do
    case $1 in
      -d|--dest)
        dest_path="$2"
        shift; shift
        ;;
      -l|--load-local-runagfile)
        load_local_runagfile=true
        shift
        ;;
      -*)
        softfail "Unknown argument: $1" || return $?
        ;;
      *)
        break
        ;;
    esac
  done

  cd "${dest_path}" || softfail || return $?

  local current_date; current_date="$(date --utc "+%Y%m%dT%H%M%SZ")" || softfail || return $?

  local release_dir; release_dir="$(mktemp -d "releases/${current_date}-XXX")" || softfail "Unable to make release directory" || return $?

  git clone --quiet repo "${release_dir}" || softfail || return $?

  release::build_and_deploy_services ${load_local_runagfile:+"--load-local-runagfile"} --release-dir "${release_dir}" || softfail || return $?

  ln --symbolic --force --no-dereference "${release_dir}" "current" || softfail || return $?

  touch "${release_dir}/.successful-release-flag" || softfail || return $?

  release::cleanup --kind successful || softfail || return $?
  release::cleanup --kind non-successful || softfail || return $?
)

release::build_and_deploy_services() (
  local release_dir
  local load_local_runagfile

  while [ "$#" -gt 0 ]; do
    case $1 in
      -d|--release-dir)
        release_dir="$2"
        shift; shift
        ;;
      -l|--load-local-runagfile)
        load_local_runagfile=true
        shift
        ;;
      -*)
        softfail "Unknown argument: $1" || return $?
        ;;
      *)
        break
        ;;
    esac
  done

  cd "${release_dir}" || softfail || return $?

  if [ "${load_local_runagfile}" = true ]; then
    runagfile::load --working-directory-only --tolerate-absence || softfail || return $?
  fi

  if declare -F release::env >/dev/null; then
    release::env || softfail || return $?
  fi

  if declare -F release::build >/dev/null; then
    release::build || softfail || return $?
  fi

  if declare -F release::deploy_services >/dev/null; then
    release::deploy_services || softfail || return $?
  fi
)

# release::build() {

# release::release::deploy_services() {

release::cleanup() {
  local cleanup_kind
  local keep_amount=6

  while [ "$#" -gt 0 ]; do
    case $1 in
      -k|--kind)
        cleanup_kind="$2"
        shift; shift
        ;;
      -p|--keep)
        keep_amount="$2"
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

  local release_item; for release_item in releases/*; do
    if [ -d "${release_item}" ]; then
      if [ "${cleanup_kind}" = successful ] && [ -f "${release_item}/.successful-release-flag" ]; then
        echo "${release_item}"
      elif [ "${cleanup_kind}" = non-successful ] && [ ! -f "${release_item}/.successful-release-flag" ]; then
        echo "${release_item}"
      fi
    fi
  done | sort | head --lines="-${keep_amount}" | \
  while IFS="" read -r release_item; do
    echo "Cleaning up past release ${PWD}/${release_item}..."
    rm -rf "${release_item:?}" || softfail || return $?
  done

  if [[ "${PIPESTATUS[*]}" =~ [^0[:space:]] ]]; then
    softfail || return $?
  fi
}
