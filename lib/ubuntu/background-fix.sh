#!/bin/bash

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

case $1/$2 in
  pre/*)
    ;;
  post/*)
    if [ -f /var/cache/background-fix-state ]; then
      rm /var/cache/background-fix-state
      su - stan bash -c "DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1000/bus gsettings set org.gnome.desktop.background picture-uri 'file:///usr/share/backgrounds/warty-final-ubuntu.png'"
    else
      touch /var/cache/background-fix-state
      su - stan bash -c "DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1000/bus gsettings set org.gnome.desktop.background picture-uri 'file:///usr/share/backgrounds/Disco_Dingo_Alt_Default_by_Abubakar_NK.png'"
    fi
    ;;
esac
