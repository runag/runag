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

erlang::install_dependencies::apt() {
  local packages_list=(
    autoconf # build
    build-essential # build
    fop # documentation
    libncurses5-dev # terminal
    libssh-dev # ssl
    libxml2-utils # documentation
    m4 # build
    # openjdk-11-jdk # jinterface
    # unixodbc-dev # odbc
    xsltproc # documentation
  )

  apt::install "${packages_list[@]}" || softfail || return $?
}

erlang::install_dependencies::observer::apt() {
  local packages_list; mapfile -t packages_list < <(apt-cache --names-only search '^libwxgtk-webview.*-dev' | cut -d " " -f1) || softfail || return $?

  apt::install \
    libgl1-mesa-dev \
    libglu1-mesa-dev \
    libpng-dev \
    "${packages_list[@]}" \
    || softfail || return $?
}
