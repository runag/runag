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

# Script is wrapped inside a function with a random name in hopes that
# "curl | bash" will not run some unexpected commands if download fails in the middle.
__xVhMyefCbBnZFUQtwqCs() {

# set shell options
if [ "${SOPKA_VERBOSE:-}" = true ]; then
  set -o xtrace
fi
set -o nounset

terminal::have-16-colors(){
  local amount
  [ -t 1 ] && command -v tput >/dev/null && amount="$(tput colors 2>/dev/null)" && [ -n "${amount##*[!0-9]*}" ] && [ "${amount}" -ge 16 ]
}

fail() {
  local errorColor="" normalColor=""
  if terminal::have-16-colors; then 
    errorColor="$(tput setaf 1)"
    normalColor="$(tput sgr 0)"
  fi

  echo "${errorColor}${1:-"Abnormal termination"}${normalColor}" >&2

  local i endAt=$((${#BASH_LINENO[@]}-1))
  for ((i=1; i<=endAt; i++)); do
    echo "  ${errorColor}${BASH_SOURCE[${i}]}:${BASH_LINENO[$((i-1))]}: in \`${FUNCNAME[${i}]}'${normalColor}" >&2
  done

  exit "${2:-1}"
}

task::run() {
  local highlightColor="" errorColor="" normalColor=""
  if terminal::have-16-colors; then 
    highlightColor="$(tput setaf 11)" || fail
    errorColor="$(tput setaf 9)" || fail
    normalColor="$(tput sgr 0)" || fail
  fi

  local tmpFile; tmpFile="$(mktemp)" || fail

  if [ "${SOPKA_TASKS_OMIT_TITLES:-}" != true ]; then
    echo "${highlightColor}Performing $*...${normalColor}"
  fi

  "$@" </dev/null >"${tmpFile}" 2>"${tmpFile}.stderr"
  local taskResult=$?

  if [ $taskResult = 0 ] && [ "${SOPKA_TASKS_FAIL_ON_ERRORS_IN_RUBYGEMS:-}" = true ] && grep -q "^ERROR:" "${tmpFile}.stderr"; then
    taskResult=1
  fi

  if [ $taskResult != 0 ] || [ -s "${tmpFile}.stderr" ] || [ "${SOPKA_VERBOSE:-}" = true ] || [ "${SOPKA_VERBOSE_TASKS:-}" = true ]; then
    cat "${tmpFile}" || fail
    echo -n "${errorColor}" >&2
    cat "${tmpFile}.stderr" >&2 || fail
    echo -n "${normalColor}" >&2
  fi

  rm "${tmpFile}" "${tmpFile}.stderr" || fail

  return $taskResult
}

# shellcheck disable=SC2034
apt::update() {
  SOPKA_APT_LAZY_UPDATE_HAPPENED=true
  task::run sudo apt-get update || fail
}

apt::install() {
  task::run sudo apt-get -y install "$@" || fail
}

git::install-git() {
  if [[ "${OSTYPE}" =~ ^linux ]]; then
    if ! command -v git >/dev/null; then
      if command -v apt-get >/dev/null; then
        apt::update || fail
        apt::install git || fail
      else
        fail "Unable to install git, apt-get not found"
      fi
    fi
  fi

  # on macos that will start git install process
  git --version >/dev/null || fail
}

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

sopka::add() {
  local packageId="$1"
  local dest; dest="$(echo "${packageId}" | tr "/" "-")" || fail
  git::place-up-to-date-clone "https://github.com/${packageId}.git" "${HOME}/.sopka/sopkafiles/github-${dest}" || fail
}


git::install-git || fail

git::place-up-to-date-clone "https://github.com/senotrusov/sopka.git" "${HOME}/.sopka" || fail

if [ -n "${1:-}" ] && [ "$1" != "--" ]; then
  sopka::add "$1" || fail
fi

"${HOME}/.sopka/bin/sopka" "${@:2}" || fail

}; __xVhMyefCbBnZFUQtwqCs "$@" || return $?
