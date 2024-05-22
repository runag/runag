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

postfix::install() {
  local mailname
  local root_address

  while [ "$#" -gt 0 ]; do
    case "$1" in
      -m|--mailname)
        mailname="$2"
        shift; shift
        ;;
      -r|--root-address)
        root_address="$2"
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

  # to get those names use the following:
  #   sudo apt install debconf-utils
  #   sudo debconf-get-selections | grep ^postfix

  sudo debconf-set-selections <<EOF || fail
postfix postfix/mailname string ${mailname}
postfix postfix/main_mailer_type select Internet Site
postfix postfix/root_address string ${root_address}
EOF

  apt::install postfix || fail

  # I could not set to this value using postfix/destinations in debconf-set-selections so I doing that manually
  sudo sed --in-place -E "s/^mydestination.*$/mydestination = localhost.localdomain, localhost/g" /etc/postfix/main.cf || fail

  sudo systemctl reload postfix || fail
}
