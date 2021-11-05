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

leaseweb::domains::list() {(
  local domain="$1"
  local apiKey; apiKey="$(cat "${LEASEWEB_KEY_FILE}")" || softfail || return $?

  curl \
    --fail \
    --header "X-Lsw-Auth: ${apiKey}" \
    --request GET \
    --show-error \
    --silent \
    --url "https://api.leaseweb.com/hosting/v2/domains/${domain}/resourceRecordSets" \
      || softfail || return $?
)}

leaseweb::domains::set-record() {(
  local record="$1"
  local recordTtl="$2"
  local recordType="$3"
  local recordData="$4"

  local domain; domain="$(leaseweb::domains::extract-domain-from-host "${record}")" || softfail || return $?
  local apiKey; apiKey="$(cat "${LEASEWEB_KEY_FILE}")" || softfail || return $?

  if [ "${recordTtl}" = 1m ]; then
    recordTtl=60
  elif [ "${recordTtl}" = 5m ]; then
    recordTtl=300
  elif [ "${recordTtl}" = 30m ]; then
    recordTtl=1800
  elif [ "${recordTtl}" = 1h ]; then
    recordTtl=3600
  elif [ "${recordTtl}" = 4h ]; then
    recordTtl=14400
  elif [ "${recordTtl}" = 8h ]; then
    recordTtl=28800
  elif [ "${recordTtl}" = 12h ]; then
    recordTtl=43200
  elif [ "${recordTtl}" = 1d ]; then
    recordTtl=86400
  fi

  local domainExists; domainExists="$(curl \
    --header "X-Lsw-Auth: ${apiKey}" \
    --output /dev/null \
    --request GET \
    --show-error \
    --silent \
    --url https://api.leaseweb.com/hosting/v2/domains/${domain}/resourceRecordSets/${record}./${recordType} \
    --write-out "%{http_code}" \
    )" || softfail || return $?

  if [ "${domainExists}" = 200 ]; then
    curl \
      --data "{ \"content\": [\"${recordData}\"], \"ttl\": ${recordTtl} }" \
      --fail \
      --header "content-type: application/json" \
      --header "X-Lsw-Auth: ${apiKey}" \
      --output /dev/null \
      --request PUT \
      --show-error \
      --silent \
      --url "https://api.leaseweb.com/hosting/v2/domains/${domain}/resourceRecordSets/${record}./${recordType}" \
        || softfail || return $?

  elif [ "$domainExists" = 404 ]; then
    curl \
      --data "{ \"name\": \"${record}.\", \"type\": \"${recordType}\", \"content\": [\"${recordData}\"], \"ttl\": ${recordTtl} }" \
      --fail \
      --header "content-type: application/json" \
      --header "X-Lsw-Auth: ${apiKey}" \
      --output /dev/null \
      --request POST \
      --show-error \
      --silent \
      --url "https://api.leaseweb.com/hosting/v2/domains/${domain}/resourceRecordSets" \
        || softfail || return $?

  else
    softfail "Domain check returned HTTP status code: ${domainExists}"
    return $?
  fi
)}

leaseweb::domains::clear-record() {(
  local record="$1"
  local recordType="$2"

  local domain; domain="$(leaseweb::domains::extract-domain-from-host "${record}")" || softfail || return $?
  local apiKey; apiKey="$(cat "${LEASEWEB_KEY_FILE}")" || softfail || return $?

  curl \
    --fail \
    --header "X-Lsw-Auth: ${apiKey}" \
    --output /dev/null \
    --request DELETE \
    --show-error \
    --silent \
    --url "https://api.leaseweb.com/hosting/v2/domains/${domain}/resourceRecordSets/${record}./${recordType}" \
      || softfail || return $?
)}

leaseweb::domains::set-acme-challenge() {
  export LEASEWEB_KEY_FILE="$1"
  leaseweb::domains::set-record "_acme-challenge.${CERTBOT_DOMAIN}" 1m TXT "${CERTBOT_VALIDATION}" || softfail || return $?
}

leaseweb::domains::clear-acme-challenge() {
  export LEASEWEB_KEY_FILE="$1"
  leaseweb::domains::clear-record "_acme-challenge.${CERTBOT_DOMAIN}" TXT || softfail || return $?
}

leaseweb::domains::extract-domain-from-host() {
  grep -E --only-matching "[a-zA-Z0-9\-]+\.[a-zA-Z0-9\-]+$" <<< "$1" || softfail || return $?
}
