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

tailscale::install() {
  local distributorId codename

  distributorId="$(linux::get-distributor-id-lowercase)" || fail
  codename="$(lsb_release --codename --short)" || fail

  curl --fail --silent --show-error --location \
    "https://pkgs.tailscale.com/stable/${distributorId}/${codename}.gpg" | sudo apt-key add -
  test "${PIPESTATUS[*]}" = "0 0" || fail

  curl --fail --silent --show-error --location \
    "https://pkgs.tailscale.com/stable/${distributorId}/${codename}.list" | sudo tee /etc/apt/sources.list.d/tailscale.list
  test "${PIPESTATUS[*]}" = "0 0" || fail

  apt::update || fail
  apt::install tailscale || fail
}

tailscale::is-logged-out() {
  local statusString; statusString="$(tailscale status)"
  local statusCode=$?

  if [ "${statusCode}" = 1 ] && [ "${statusString}" = "Logged out." ]; then
    return 0
  else
    return 1
  fi
}

tailscale::issue-2541-workaround() {
  if ip address show tailscale0; then
    if ! ip address show tailscale0 | grep --quiet --fixed-strings "inet"; then
      echo "tailscale::issue-2541-workaround: about to restart tailscaled"
      sudo systemctl restart tailscaled || fail
    fi
  fi
}

tailscale::install-issue-2541-workaround() {
  file::sudo-write /usr/local/bin/tailscale-issue-2541-workaround 755 <<EOF || fail
#!/usr/bin/env bash
$(sopka::print-license)
$(declare -f fail)
$(declare -f tailscale::issue-2541-workaround)
tailscale::issue-2541-workaround || fail
EOF

  file::sudo-write /etc/systemd/system/tailscale-issue-2541-workaround.service <<EOF || fail
[Unit]
Description=tailscale-issue-2541-workaround

[Service]
Type=oneshot
ExecStart=/usr/local/bin/tailscale-issue-2541-workaround
WorkingDirectory=/
EOF

  file::sudo-write /etc/systemd/system/tailscale-issue-2541-workaround.timer <<EOF || fail
[Unit]
Description=tailscale-issue-2541-workaround

[Timer]
OnCalendar=minutely
Persistent=true

[Install]
WantedBy=timers.target
EOF

  sudo systemctl daemon-reload || fail
  sudo systemctl reenable tailscale-issue-2541-workaround.timer || fail
  sudo systemctl start tailscale-issue-2541-workaround.timer || fail
}
