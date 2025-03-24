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

# https://github.com/asdf-vm/asdf-erlang?tab=readme-ov-file#before-asdf-install

erlang::extend_package_list::debian() {
  package_list+=(
    autoconf         # build
    build-essential  # build
    fop              # documentation
    libncurses5-dev  # terminal
    libssh-dev       # ssl
    libxml2-utils    # documentation
    m4               # build
    # openjdk-11-jdk # jinterface
    # unixodbc-dev   # odbc
    xsltproc         # documentation
  )
}

erlang::extend_package_list::arch() {
  package_list+=(
    base-devel # build tools
    fop # documentation
    libssh # ssl
    libxslt # documentation
    ncurses # terminal
  )
}

erlang::extend_package_list::observer::debian() {
  # mapfile requires Bash 4.0 or newer (released in 2009)
  local -a webview_packages; mapfile -t webview_packages < <(apt-cache --names-only search '^libwxgtk-webview.*-dev' | cut -d " " -f 1) || softfail || return $?

  package_list+=(
    libgl1-mesa-dev
    libglu1-mesa-dev
    libpng-dev
    "${webview_packages[@]}"
  )
}

erlang::extend_package_list::observer::arch() {
  package_list+=(
    glu
    libpng
    mesa
    wxwidgets-gtk3
  )
}
