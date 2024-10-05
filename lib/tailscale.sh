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

tailscale::install() (
  # Load operating system identification data
  . /etc/os-release || softfail || return $?

  if [ "${ID:-}" = debian ] || [ "${ID_LIKE:-}" = debian ]; then
    apt::add_source_with_key "tailscale" \
      "https://pkgs.tailscale.com/stable/${ID} ${VERSION_CODENAME} main" \
      "https://pkgs.tailscale.com/stable/${ID}/${VERSION_CODENAME}.gpg" || softfail || return $?

    apt::install tailscale || softfail || return $?

  elif [ "${ID:-}" = arch ]; then
    sudo pacman --sync --needed --noconfirm tailscale || softfail || return $?
  fi

  sudo systemctl --quiet --now enable tailscaled || softfail || return $?
)

tailscale::is_logged_in() {
  # this function is intent to use fail (and not softfail) in case of errors
  local backend_state; backend_state="$(tailscale status --json | jq --raw-output --exit-status .BackendState; test "${PIPESTATUS[*]}" = "0 0")" || fail "Unable to obtain tailscale status" # no softfail here!

  if [ "${backend_state}" = "NeedsLogin" ]; then
    return 1
  else
    return 0
  fi
}

tailscale::issue_2541_workaround() {
  if ip address show tailscale0 >/dev/null 2>&1; then
    if ! ip address show tailscale0 | grep -qF "inet"; then
      echo "tailscale::issue_2541_workaround: about to restart tailscaled"
      sudo systemctl restart tailscaled || fail "Unable to restart tailscaled"
    fi
  fi
}

tailscale::install_issue_2541_workaround() {
  temp_file="$(mktemp)" || fail
  {
    runag::mini_library || fail

    declare -f tailscale::issue_2541_workaround || fail

    echo 'set -o nounset'
    echo 'tailscale::issue_2541_workaround || fail'

  } >"${temp_file}" || fail
  
  file::write --absorb "${temp_file}" --sudo --mode 0755 /usr/local/bin/tailscale-issue-2541-workaround || softfail || return $?

  file::write --sudo --mode 0644 /etc/systemd/system/tailscale-issue-2541-workaround.service <<EOF || softfail || return $?
[Unit]
Description=tailscale-issue-2541-workaround

[Service]
Type=oneshot
ExecStart=/usr/local/bin/tailscale-issue-2541-workaround
WorkingDirectory=/
EOF

  file::write --sudo --mode 0644 /etc/systemd/system/tailscale-issue-2541-workaround.timer <<EOF || softfail || return $?
[Unit]
Description=tailscale-issue-2541-workaround

[Timer]
OnCalendar=minutely
Persistent=true

[Install]
WantedBy=timers.target
EOF

  sudo systemctl --quiet reenable tailscale-issue-2541-workaround.timer || softfail || return $?
  sudo systemctl start tailscale-issue-2541-workaround.timer || softfail || return $?
}
