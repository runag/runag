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

tailscale::install() {
  local distributor_id distribution_codename

  distributor_id="$(linux::get_distributor_id_lowercase)" || fail
  distribution_codename="$(lsb_release --codename --short)" || fail

  curl --fail --silent --show-error --location \
    "https://pkgs.tailscale.com/stable/${distributor_id}/${distribution_codename}.gpg" | sudo apt-key add -
  test "${PIPESTATUS[*]}" = "0 0" || fail

  curl --fail --silent --show-error --location \
    "https://pkgs.tailscale.com/stable/${distributor_id}/${distribution_codename}.list" | sudo tee /etc/apt/sources.list.d/tailscale.list
  test "${PIPESTATUS[*]}" = "0 0" || fail

  apt::update || fail
  apt::install tailscale || fail
}

tailscale::is_logged_out() {
  local status_string; status_string="$(tailscale status)"
  local status_code=$?

  if [ "${status_code}" = 1 ] && [ "${status_string}" = "Logged out." ]; then
    return 0
  else
    return 1
  fi
}

tailscale::issue_2541_workaround() {
  if ip address show tailscale0 >/dev/null 2>&1; then
    if ! ip address show tailscale0 | grep -qF "inet"; then
      echo "tailscale::issue_2541_workaround: about to restart tailscaled"
      sudo systemctl restart tailscaled || { echo "Unable to restart tailscaled" >&2; exit 1; }
    fi
  fi
}

tailscale::install_issue_2541_workaround() {
  file::sudo_write /usr/local/bin/tailscale-issue-2541-workaround 755 <<SHELL || fail
#!/usr/bin/env bash
$(sopka::print_license)
$(declare -f tailscale::issue_2541_workaround)
tailscale::issue_2541_workaround || { echo "Unable to perform tailscale::issue_2541_workaround" >&2; exit 1; }
SHELL

  file::sudo_write /etc/systemd/system/tailscale-issue-2541-workaround.service <<EOF || fail
[Unit]
Description=tailscale-issue-2541-workaround

[Service]
Type=oneshot
ExecStart=/usr/local/bin/tailscale-issue-2541-workaround
WorkingDirectory=/
EOF

  file::sudo_write /etc/systemd/system/tailscale-issue-2541-workaround.timer <<EOF || fail
[Unit]
Description=tailscale-issue-2541-workaround

[Timer]
OnCalendar=minutely
Persistent=true

[Install]
WantedBy=timers.target
EOF

  sudo systemctl --quiet reenable tailscale-issue-2541-workaround.timer || fail
  sudo systemctl start tailscale-issue-2541-workaround.timer || fail
}
