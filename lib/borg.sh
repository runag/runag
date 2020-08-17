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

borg::menu() {
  local list=()

  list+=(borg::init)
  list+=(borg::check-verify)
  list+=(borg::view)
  list+=(borg::mount)
  list+=(borg::umount)
  list+=(borg::export-key)
  list+=(borg::connect-sftp)

  list+=(borg::systemd::install)
  list+=(borg::systemd::disable)

  list+=(borg::systemd::start)
  list+=(borg::systemd::stop)

  list+=(borg::systemd::start-timer)
  list+=(borg::systemd::stop-timer)

  list+=(borg::systemd::status)
  list+=(borg::systemd::log)

  menu::select-and-run "${list[@]}" || fail
}

borg::configure-backup-credentials() {
  local backupName="$1"

  local credentialsFile="${HOME}/.${backupName}.backup-credentials"
  local storageBwItem="${backupName} backup storage"
  local passphraseBwItem="${backupName} backup passphrase"
  local backupPath="borg-backups/${backupName}"

  if [ ! -f "${credentialsFile}" ]; then
    bitwarden::unlock || fail

    local storageUsername; storageUsername="$(bw get username "${storageBwItem}")" || fail
    local storageUri; storageUri="$(bw get uri "${storageBwItem}")" || fail
    local storageHost; storageHost="$(echo "${storageUri}" | cut -d ":" -f 1)" || fail
    local storagePort; storagePort="$(echo "${storageUri}" | cut -d ":" -f 2)" || fail
    local passphrase; passphrase="$(bw get password "${passphraseBwItem}")" || fail

    ssh::add-host-to-known-hosts "${storageHost}" "${storagePort}" || fail

    builtin printf "export BACKUP_NAME=$(printf "%q" "${backupName}")\nexport STORAGE_USERNAME=$(printf "%q" "${storageUsername}")\nexport STORAGE_HOST=$(printf "%q" "${storageHost}")\nexport STORAGE_PORT=$(printf "%q" "${storagePort}")\nexport BORG_REPO=$(printf "%q" "ssh://${storageUsername}@${storageUri}/./${backupPath}")\nexport BORG_PASSPHRASE=$(printf "%q" "${passphrase}")\n" | (umask 077 && tee "${credentialsFile}" >/dev/null) || fail
  fi
}

borg::init() {
  borg init --encryption keyfile-blake2 --make-parent-dirs || fail
  borg::export-key || fail
}

borg::check-verify() {
  borg check --verify-data || fail
}

borg::view() {
  borg list || fail
  borg info || fail
}

borg::mount() {
  local mountPoint="${HOME}/${BACKUP_NAME}.archive"
  mkdir -p "${mountPoint}" || fail
  borg mount "${BORG_REPO}" "${mountPoint}" || fail
}

borg::umount() {
  local mountPoint="${HOME}/${BACKUP_NAME}.archive"
  borg umount "${mountPoint}" || fail
}

borg::export-key() {
  local exportPath; exportPath="${HOME}/${BACKUP_NAME}-$(date +"%Y%m%dT%H%M%SZ")" || fail

  borg key export "${BORG_REPO}" "${exportPath}.key" || fail
  borg key export --qr-html "${BORG_REPO}" "${exportPath}.key.html" || fail
}

borg::connect-sftp() {
  sftp -P "${STORAGE_PORT}" "${STORAGE_USERNAME}@${STORAGE_HOST}" || fail
}

borg::systemd::install() {
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
NoNewPrivileges=true
EOF

tee "${servicesPath}/${BACKUP_NAME}.timer" <<EOF || fail
[Unit]
Description=Backup service timer for ${BACKUP_NAME}

[Timer]
OnCalendar=hourly
RandomizedDelaySec=600

[Install]
WantedBy=timers.target
EOF

  systemctl --user reenable "${BACKUP_NAME}.service" || fail
  systemctl --user reenable "${BACKUP_NAME}.timer" || fail

  systemctl --user start "${BACKUP_NAME}.timer" || fail
}

borg::systemd::disable() {
  borg::systemd::pause || fail

  systemctl --user disable "${BACKUP_NAME}.timer" || fail
  systemctl --user disable "${BACKUP_NAME}.service" || fail
}

borg::systemd::start() {
  systemctl --user --no-block start "${BACKUP_NAME}.service" || fail
}

borg::systemd::stop() {
  systemctl --user stop "${BACKUP_NAME}.service" || fail
}

borg::systemd::start-timer() {
  systemctl --user start "${BACKUP_NAME}.timer" || fail
}

borg::systemd::stop-timer() {
  if systemctl --user is-enabled "${BACKUP_NAME}.timer" >/dev/null 2>&1; then
    systemctl --user stop "${BACKUP_NAME}.timer" || fail
  fi
}

borg::systemd::status() {
  systemctl --user status "${BACKUP_NAME}.service"
  systemctl --user status "${BACKUP_NAME}.timer"
  systemctl --user list-timers "${BACKUP_NAME}.timer" --all
}

borg::systemd::log() {
  journalctl --user -u "${BACKUP_NAME}.service" --since today
}
