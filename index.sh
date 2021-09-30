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

sopka::load-lib() {
  local selfDir; selfDir="$(dirname "${BASH_SOURCE[0]}")" || { echo "Sopka: Unable to get dirname of index.sh ($?)" >&2; exit 1; }

  . "${selfDir}/lib/terminal.sh" || { echo "Sopka: Unable to load lib/terminal.sh ($?)" >&2; exit 1; }
  . "${selfDir}/lib/fail.sh" || { echo "Sopka: Unable to load lib/fail.sh ($?)" >&2; exit 1; }

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
  . "${selfDir}/lib/rsync.sh" || fail
  . "${selfDir}/lib/ruby.sh" || fail
  . "${selfDir}/lib/shell.sh" || fail
  . "${selfDir}/lib/sopka-menu.sh" || fail
  . "${selfDir}/lib/sopka.sh" || fail
  . "${selfDir}/lib/ssh.sh" || fail
  . "${selfDir}/lib/sublime.sh" || fail
  . "${selfDir}/lib/syncthing.sh" || fail
  . "${selfDir}/lib/systemd.sh" || fail
  . "${selfDir}/lib/tailscale.sh" || fail
  . "${selfDir}/lib/task.sh" || fail
  . "${selfDir}/lib/vmware.sh" || fail
  . "${selfDir}/lib/vscode.sh" || fail
}

sopka::load-lib || fail
