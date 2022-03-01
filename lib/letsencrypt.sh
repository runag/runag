#!/usr/bin/env bash

#  Copyright 2012-2022 Stanislav Senotrusov <stan@senotrusov.com>
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

letsencrypt::agree_tos_and_register_unsafely_without_email() {
  if [ ! -d /etc/letsencrypt/accounts ] || [ -z "$(ls -A /etc/letsencrypt/accounts)" ]; then
    sudo letsencrypt register \
      --agree-tos \
      --register-unsafely-without-email \
      --non-interactive \
        || softfail || return $?
  fi
}

letsencrypt::make_domains_string() {
  local domains_list; IFS=" " read -r -a domains_list <<< "${LETSENCRYPT_DOMAINS:-"${APP_DOMAINS:?}"}" || softfail || return $?
  local domains_string; printf -v domains_string ",%s" "${domains_list[@]}" || softfail || return $?
  echo "${domains_string:1}"
}
