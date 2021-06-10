#!/usr/bin/env bash

#  Copyright 2012-2020 Stanislav Senotrusov <stan@senotrusov.com>
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

ubuntu::deploy-minimal-application-server() {
  # update and upgrade
  apt::lazy-update || fail

  # basic tools, contains curl so it have to be first
  ubuntu::packages::install-basic-tools || fail

  # devtools
  ubuntu::packages::install-devtools || fail

  # shellrcd
  shell::install-shellrc-directory-loader "${HOME}/.bashrc" || fail
  shell::install-nano-editor-shellrc || fail
  shell::install-direnv-loader-shellrc || fail

  # install ruby
  ruby::ubuntu::install || fail

  # install nodejs
  nodejs::apt::install || fail

  # deploy sshd
  sshd::ubuntu::install-and-configure || fail
}
