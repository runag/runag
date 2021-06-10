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

restic::menu() {
  local list=()

  list+=(restic::init)
  list+=(restic::check-and-read-data)
  list+=(restic::forget-and-prune)
  list+=(restic::view)
  list+=(restic::mount)
  list+=(restic::umount)

  list+=(restic::systemd::init-service)
  list+=(restic::systemd::start-service)
  list+=(restic::systemd::stop-service)

  list+=(restic::systemd::enable-timer)
  list+=(restic::systemd::disable-timer)

  list+=(restic::systemd::status)
  list+=(restic::systemd::log)

  menu::select-and-run "${list[@]}" || fail
}

restic::init() {
  restic init || fail
}

restic::check-and-read-data() {
  restic check --check-unused --read-data || fail
}

restic::forget-and-prune() {
  restic forget \
    --prune \
    --keep-within 10d \
    --keep-daily 30 \
    --keep-weekly 14 \
    --keep-monthly 24 || fail
}

restic::view() {
  restic snapshots || fail
}

restic::mount() {
  local mountPoint="${HOME}/${BACKUP_NAME}.archive"
  mkdir -p "${mountPoint}" || fail
  restic mount "${mountPoint}" || fail
}

restic::umount() {
  local mountPoint="${HOME}/${BACKUP_NAME}.archive"
  umount "${mountPoint}" || fail
}

restic::systemd::init-service() {
  if [ -n "${1:-}" ]; then
    local -n options=$1
  else
    declare -A options
  fi

  local servicesPath="${HOME}/.config/systemd/user"
  mkdir -p "${servicesPath}" || fail

  tee "${servicesPath}/${BACKUP_NAME}.service" <<EOF || fail
[Unit]
Description=Backup service for ${BACKUP_NAME}

[Service]
Type=oneshot
ExecStart=${SOPKA_DIR}/bin/sopka backup::${BACKUP_NAME}::create
SyslogIdentifier=${BACKUP_NAME}
ProtectSystem=full
PrivateTmp=true
NoNewPrivileges=${options[NoNewPrivileges]:-"true"}
EOF

  systemctl --user reenable "${BACKUP_NAME}.service" || fail
}

restic::systemd::start-service() {
  systemctl --user --no-block start "${BACKUP_NAME}.service" || fail
}

restic::systemd::stop-service() {
  systemctl --user stop "${BACKUP_NAME}.service" || fail
}

restic::systemd::enable-timer() {
  if [ -n "${1:-}" ]; then
    local -n options=$1
  else
    declare -A options
  fi

  local servicesPath="${HOME}/.config/systemd/user"
  mkdir -p "${servicesPath}" || fail

  tee "${servicesPath}/${BACKUP_NAME}.timer" <<EOF || fail
[Unit]
Description=Backup service timer for ${BACKUP_NAME}

[Timer]
OnCalendar=${options[OnCalendar]:-"hourly"}
RandomizedDelaySec=${options[RandomizedDelaySec]:-"300"}

[Install]
WantedBy=timers.target
EOF

  systemctl --user reenable "${BACKUP_NAME}.timer" || fail
  systemctl --user start "${BACKUP_NAME}.timer" || fail
}

restic::systemd::disable-timer() {
  systemctl --user disable "${BACKUP_NAME}.timer" || fail
}

restic::systemd::status() {
  systemctl --user status "${BACKUP_NAME}.service"
  echo ""
  systemctl --user status "${BACKUP_NAME}.timer"
  echo ""
  systemctl --user list-timers "${BACKUP_NAME}.timer" --all || fail
}

restic::systemd::log() {
  journalctl --user -u "${BACKUP_NAME}.service" --since today || fail
}
