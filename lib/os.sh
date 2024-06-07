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

os::hostname() {
  if [[ "${OSTYPE}" =~ ^msys ]]; then
    echo "${HOSTNAME}" | tr '[:upper:]' '[:lower:]'
    test "${PIPESTATUS[*]}" = "0 0" || softfail || return $?

  elif [[ "${OSTYPE}" =~ ^darwin ]]; then
    hostname # TODO: check it

  elif [[ "${OSTYPE}" =~ ^linux ]]; then
    hostnamectl --static status
  fi
}

os::machine_id() {
  if [[ "${OSTYPE}" =~ ^linux ]]; then
    if [ "$(systemd-detect-virt)" = "vmware" ]; then
      sudo dmidecode -t system | grep "^[[:blank:]]*Serial Number: VMware-" | sed "s/^[[:blank:]]*Serial Number: VMware-//" | sed "s/ //g"
      test "${PIPESTATUS[*]}" = "0 0 0 0" && return
    fi

    if systemd-detect-virt --quiet; then
      sudo dmidecode --string system-uuid && return
    fi

    cat /etc/machine-id || softfail || return $?
  fi
}
