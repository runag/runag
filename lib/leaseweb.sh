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

leaseweb::domains::get_short_record() {
  local record="$1"
  local record_type="$2"

  leaseweb::domains::list "${record}" "${record_type}" | jq --exit-status 'del(._links, .editable)'
  test "${PIPESTATUS[*]}" = "0 0" || softfail || return $?
}

leaseweb::domains::list() {
  local record="$1"
  local record_type="$2"

  local domain; domain="$(leaseweb::domains::extract_domain_from_host "${record}")" || softfail || return $?

  curl \
    --fail \
    --header "X-Lsw-Auth: ${LEASEWEB_API_KEY}" \
    --request GET \
    --show-error \
    --silent \
    --url "https://api.leaseweb.com/hosting/v2/domains/${domain}/resourceRecordSets/${record}./${record_type}" \
      || softfail || return $?
}

# 1m 5m 30m 1h 4h 8h 12h 1d
leaseweb::domains::set_record() {
  local record="$1"
  local record_ttl="$2"
  local record_type="$3"
  local record_data="$4"

  local domain; domain="$(leaseweb::domains::extract_domain_from_host "${record}")" || softfail || return $?

  if [ "${record_ttl}" = 1m ]; then
    record_ttl=60
  elif [ "${record_ttl}" = 5m ]; then
    record_ttl=300
  elif [ "${record_ttl}" = 30m ]; then
    record_ttl=1800
  elif [ "${record_ttl}" = 1h ]; then
    record_ttl=3600
  elif [ "${record_ttl}" = 4h ]; then
    record_ttl=14400
  elif [ "${record_ttl}" = 8h ]; then
    record_ttl=28800
  elif [ "${record_ttl}" = 12h ]; then
    record_ttl=43200
  elif [ "${record_ttl}" = 1d ]; then
    record_ttl=86400
  fi

  local domain_exists; domain_exists="$(curl \
    --header "X-Lsw-Auth: ${LEASEWEB_API_KEY}" \
    --output /dev/null \
    --request GET \
    --show-error \
    --silent \
    --url "https://api.leaseweb.com/hosting/v2/domains/${domain}/resourceRecordSets/${record}./${record_type}" \
    --write-out "%{http_code}" \
    )" || softfail || return $?

  if [ "${domain_exists}" = 200 ]; then
    curl \
      --data "{ \"content\": [\"${record_data}\"], \"ttl\": ${record_ttl} }" \
      --fail \
      --header "content-type: application/json" \
      --header "X-Lsw-Auth: ${LEASEWEB_API_KEY}" \
      --output /dev/null \
      --request PUT \
      --show-error \
      --silent \
      --url "https://api.leaseweb.com/hosting/v2/domains/${domain}/resourceRecordSets/${record}./${record_type}" \
        || softfail || return $?

  elif [ "${domain_exists}" = 404 ]; then
    curl \
      --data "{ \"name\": \"${record}.\", \"type\": \"${record_type}\", \"content\": [\"${record_data}\"], \"ttl\": ${record_ttl} }" \
      --fail \
      --header "content-type: application/json" \
      --header "X-Lsw-Auth: ${LEASEWEB_API_KEY}" \
      --output /dev/null \
      --request POST \
      --show-error \
      --silent \
      --url "https://api.leaseweb.com/hosting/v2/domains/${domain}/resourceRecordSets" \
        || softfail || return $?

  else
    softfail "Domain check returned HTTP status code: ${domain_exists}"
    return $?
  fi
}

leaseweb::domains::clear_record() {
  local record="$1"
  local record_type="$2"

  local domain; domain="$(leaseweb::domains::extract_domain_from_host "${record}")" || softfail || return $?

  curl \
    --fail \
    --header "X-Lsw-Auth: ${LEASEWEB_API_KEY}" \
    --output /dev/null \
    --request DELETE \
    --show-error \
    --silent \
    --url "https://api.leaseweb.com/hosting/v2/domains/${domain}/resourceRecordSets/${record}./${record_type}" \
      || softfail || return $?
}

leaseweb::domains::set_acme_challenge() {
  leaseweb::domains::set_record "_acme-challenge.${CERTBOT_DOMAIN}" 1m TXT "${CERTBOT_VALIDATION}" || softfail || return $?
}

leaseweb::domains::clear_acme_challenge() {
  leaseweb::domains::clear_record "_acme-challenge.${CERTBOT_DOMAIN}" TXT || softfail || return $?
}

leaseweb::domains::extract_domain_from_host() {
  grep -E --only-matching "[a-zA-Z0-9\-]+\.[a-zA-Z0-9\-]+$" <<< "$1" || softfail || return $?
}

leaseweb::function_sources() {
  declare -f leaseweb::domains::get_short_record || softfail || return $?
  declare -f leaseweb::domains::list || softfail || return $?
  declare -f leaseweb::domains::set_record || softfail || return $?
  declare -f leaseweb::domains::clear_record || softfail || return $?
  declare -f leaseweb::domains::set_acme_challenge || softfail || return $?
  declare -f leaseweb::domains::clear_acme_challenge || softfail || return $?
  declare -f leaseweb::domains::extract_domain_from_host || softfail || return $?
}
