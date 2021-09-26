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

# TODO: Check if its working after recent changes
# based on https://unix.stackexchange.com/questions/108174/how-to-persistently-control-maximum-system-resource-consumption-on-mac
macos::increase-maxfiles-limit() {
  local softLimit="${1:-"262144"}"
  local hardLimit="${2:-"524288"}"

  local label="sopka.limit.maxfiles"
  local dst="/Library/LaunchDaemons/${label}.plist"

  if [ ! -f "${dst}" ]; then
    file::sudo-write "${dst}" 644 root wheel <<EOF || fail
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
        "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
  <dict>
    <key>Label</key>
    <string>${label}</string>
    <key>ProgramArguments</key>
    <array>
      <string>launchctl</string>
      <string>limit</string>
      <string>maxfiles</string>
      <string>${softLimit}</string>
      <string>${hardLimit}</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>ServiceIPC</key>
    <false/>
  </dict>
</plist>
EOF
    echo "increase-maxfiles-limit: Please reboot your computer" >&2
  fi
}

macos::hide-folder() {
  if [ -d "$1" ]; then
    chflags hidden "$1" || fail
  fi
}

macos::install-homebrew() {
  if ! command -v brew >/dev/null; then
    /usr/bin/ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)" </dev/null || fail "Unable to install homebrew"
  fi
}
