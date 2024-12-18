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

erlang::install_dependencies() (
  . /etc/os-release || softfail || return $?

  # https://github.com/asdf-vm/asdf-erlang?tab=readme-ov-file#before-asdf-install

  if [ "${ID:-}" = debian ] || [ "${ID_LIKE:-}" = debian ]; then
    local package_list=(
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

    apt::install "${package_list[@]}" || softfail || return $?
        
  elif [ "${ID:-}" = arch ]; then
    local package_list=(
      base-devel # build tools
      fop # documentation
      libssh # ssl
      libxslt # documentation
      ncurses # terminal
    )

    sudo pacman --sync --needed --noconfirm "${package_list[@]}" || softfail || return $?
  fi
)

erlang::install_dependencies::observer() (
  . /etc/os-release || softfail || return $?

  # https://github.com/asdf-vm/asdf-erlang?tab=readme-ov-file#before-asdf-install

  if [ "${ID:-}" = debian ] || [ "${ID_LIKE:-}" = debian ]; then
    local package_list; mapfile -t package_list < <(apt-cache --names-only search '^libwxgtk-webview.*-dev' | cut -d " " -f 1) || softfail || return $?

    apt::install \
      libgl1-mesa-dev \
      libglu1-mesa-dev \
      libpng-dev \
      "${package_list[@]}" \
      || softfail || return $?
        
  elif [ "${ID:-}" = arch ]; then
    local package_list=(
      glu
      libpng
      mesa
      wxwidgets-gtk3
    )

    sudo pacman --sync --needed --noconfirm "${package_list[@]}" || softfail || return $?
  fi
)
