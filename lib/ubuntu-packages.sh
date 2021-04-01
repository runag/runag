#!/usr/bin/env bash

#  Copyright 2012-2019 Stanislav Senotrusov <stan@senotrusov.com>
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

ubuntu::packages::install-gnome-keyring-and-libsecret() {
  # gnome-keyring and libsecret (for git and ssh)
  apt::install \
    gnome-keyring \
    libsecret-tools \
    libsecret-1-0 \
    libsecret-1-dev \
      || fail

  git::ubuntu::install-credential-libsecret || fail
}

ubuntu::packages::install-basic-tools() {
  # debian-goodies is here for checkrestart
  apt::install \
    curl \
    debian-goodies \
    direnv \
    git \
    htop \
    jq \
    mc ncdu \
    p7zip-full \
    sysbench \
    tmux \
      || fail
}

ubuntu::packages::install-devtools() {
  apt::install \
    build-essential autoconf bison libncurses-dev libffi-dev libgdbm-dev libreadline-dev libssl-dev zlib1g-dev libyaml-dev libxml2-dev libxslt-dev \
    postgresql libpq-dev postgresql-contrib \
    sqlite3 libsqlite3-dev \
    redis-server \
    memcached \
    ruby-full \
    python3 python3-pip python3-psycopg2 \
    ffmpeg imagemagick ghostscript libgs-dev \
    graphviz \
    shellcheck \
    apache2-utils \
    inotify-tools \
    awscli \
      || fail
}

ubuntu::packages::install-obs-studio() {
  sudo add-apt-repository --yes ppa:obsproject/obs-studio || fail
  apt::update || fail
  apt::install obs-studio guvcview || fail
}
