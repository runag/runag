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

  git::install-libsecret-credential-helper || fail
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
    mc \
    ncdu \
    p7zip-full \
    sysbench \
    tmux \
      || fail
}

ubuntu::packages::install-developer-tools() {
  apt::install \
    apache2-utils \
    autoconf \
    awscli \
    bison \
    build-essential \
    cloud-guest-utils \
    ffmpeg \
    ghostscript \
    graphviz \
    imagemagick \
    inotify-tools \
    letsencrypt \
    libffi-dev \
    libgdbm-dev \
    libgs-dev \
    libncurses-dev \
    libpq-dev \
    libreadline-dev \
    libsqlite3-dev \
    libssl-dev \
    libxml2-dev \
    libxslt-dev \
    libyaml-dev \
    memcached \
    nginx \
    postgresql \
    postgresql-contrib \
    python3 \
    python-is-python3 \
    python3-pip \
    python3-psycopg2 \
    redis-server \
    ruby-full \
    shellcheck \
    sqlite3 \
    zlib1g-dev \
    zsh \
      || fail
}

ubuntu::packages::install-rclone() {
  if ! command -v rclone >/dev/null; then
    curl --fail --silent --show-error https://rclone.org/install.sh | sudo bash
    test "${PIPESTATUS[*]}" = "0 0" || fail "Unable to install rclone"
  fi
}
