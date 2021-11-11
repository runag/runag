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

# To get a version number, use: rbenv install -l
ruby::install-by-rbenv() {
  ruby::install-dependencies-by-apt || softfail || return $?
  rbenv::install-and-load-shellrc || softfail || return $?
  rbenv::install-ruby "$@" || softfail || return $?
}

ruby::install-and-set-global-by-rbenv() {
  local rubyVersion="$1"
  ruby::install-by-rbenv "${rubyVersion}" || softfail || return $?
  rbenv global "${rubyVersion}" || softfail || return $?
}

ruby::install-without-dependencies-by-rbenv() {
  rbenv::install-and-load-shellrc || softfail || return $?
  rbenv::install-ruby "$@" || softfail || return $?
}

ruby::install-by-apt() {
  ruby::install-dependencies-by-apt || softfail || return $?
  apt::install ruby-full || softfail || return $?
}

ruby::install-dependencies-by-apt() {
  apt::install \
    build-essential `# new rails project requires some gems to be compiled` \
    libedit-dev `# dependency to install ruby 2.7.3 using rbenv` \
    libffi-dev `# some gems require libffi, like fiddle-1.0.8.gem` \
    libsqlite3-dev `# new rails project uses sqlite` \
    libssl-dev `# dependency to install ruby 2.7.3 using rbenv` \
    zlib1g-dev `# dependency to install ruby 2.7.3 using rbenv` \
      || softfail || return $?
}

ruby::dangerously-append-nodocument-to-gemrc() {
  local gemrcFile="${HOME}/.gemrc"
  (umask 177 && touch "${gemrcFile}") || softfail || return $?
  file::append-line-unless-present "gem: --no-document" "${gemrcFile}" || softfail || return $?
}
