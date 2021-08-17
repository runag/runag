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

__xVhMyefCbBnZFUQtwqCs() {
  # set shell options
  if [ "${VERBOSE:-}" = true ]; then
    set -o xtrace
  fi
  set -o nounset

  # define fail() function
  fail() {
    local errorColor=""
    local normalColor=""

    if [ -t 2 ]; then
      local colorsAmount; colorsAmount="$(tput colors 2>/dev/null)"

      if [ $? = 0 ] && [ "${colorsAmount}" -ge 2 ]; then
        errorColor="$(tput setaf 1)"
        normalColor="$(tput sgr 0)"
      fi
    fi

    echo "${errorColor}${1:-"Abnormal termination"}${normalColor}" >&2

    local i endAt=$((${#BASH_LINENO[@]}-1))
    for ((i=1; i<=endAt; i++)); do
      echo "  ${errorColor}${BASH_SOURCE[${i}]}:${BASH_LINENO[$((i-1))]}: in \`${FUNCNAME[${i}]}'${normalColor}" >&2
    done

    exit "${2:-1}"
  }

  git::install-git() {
    if [[ "${OSTYPE}" =~ ^linux ]]; then
      if ! command -v git >/dev/null; then
        if command -v apt >/dev/null; then
          sudo apt update || fail
          sudo apt install -y git || fail
        else
          fail "Unable to install git, apt not found"
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

  git::install-git || fail

  git::place-up-to-date-clone "https://github.com/senotrusov/sopka.git" "${HOME}/.sopka" || fail

  if [ -n "${1:-}" ] && [ "$1" != "--" ]; then
    local dest; dest="$(echo "$1" | tr "/" "-")" || fail
    git::place-up-to-date-clone "https://github.com/${1}.git" "${HOME}/.sopka/files/github-${dest}" || fail
  fi

  cd "${HOME}/.sopka" || fail

  bin/sopka "${@:2}" || fail
}

# I'm wrapping the script in the function with the random name, to ensure that in case if download fails in the middle,
# then "curl | bash" will most likely not run some unexpected commands
__xVhMyefCbBnZFUQtwqCs "$@" || return $?
