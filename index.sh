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


# maybe define fail() function
if ! declare -f fail >/dev/null; then
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
fi

sopka::load-lib() {
  local selfDir; selfDir="$(dirname "${BASH_SOURCE[0]}")" || fail

  # load all libraries
  . "${selfDir}/lib/apt.sh" || fail
  . "${selfDir}/lib/benchmark.sh" || fail
  . "${selfDir}/lib/bitwarden.sh" || fail
  . "${selfDir}/lib/checksums.sh" || fail
  . "${selfDir}/lib/config.sh" || fail
  . "${selfDir}/lib/firefox.sh" || fail
  . "${selfDir}/lib/fs.sh" || fail
  . "${selfDir}/lib/git.sh" || fail
  . "${selfDir}/lib/github.sh" || fail
  . "${selfDir}/lib/imagemagick.sh" || fail
  . "${selfDir}/lib/keys.sh" || fail
  . "${selfDir}/lib/linux.sh" || fail
  . "${selfDir}/lib/macos.sh" || fail
  . "${selfDir}/lib/menu.sh" || fail
  . "${selfDir}/lib/nodejs.sh" || fail
  . "${selfDir}/lib/postgresql.sh" || fail
  . "${selfDir}/lib/rails.sh" || fail
  . "${selfDir}/lib/rclone.sh" || fail
  . "${selfDir}/lib/rsync.sh" || fail
  . "${selfDir}/lib/ruby.sh" || fail
  . "${selfDir}/lib/shell.sh" || fail
  . "${selfDir}/lib/sopka.sh" || fail
  . "${selfDir}/lib/ssh.sh" || fail
  . "${selfDir}/lib/sublime.sh" || fail
  . "${selfDir}/lib/syncthing.sh" || fail
  . "${selfDir}/lib/systemd.sh" || fail
  . "${selfDir}/lib/tailscale.sh" || fail
  . "${selfDir}/lib/vmware.sh" || fail
  . "${selfDir}/lib/vscode.sh" || fail
}

sopka::load-lib || fail
