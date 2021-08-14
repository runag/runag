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

borg::menu() {
  local list=()

  list+=(borg::init)
  list+=(borg::check-verify)
  list+=(borg::view)
  list+=(borg::mount)
  list+=(borg::umount)
  list+=(borg::export-key)
  list+=(borg::import-key)
  list+=(borg::connect-sftp)

  list+=(borg::systemd::init-service)
  list+=(borg::systemd::start-service)
  list+=(borg::systemd::stop-service)

  list+=(borg::systemd::enable-timer)
  list+=(borg::systemd::disable-timer)

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

  if [ "${UPDATE_SECRETS:-}" = "true" ] || [ ! -f "${credentialsFile}" ]; then
    bitwarden::unlock || fail

    # bitwarden-object: "? backup storage"
    # bitwarden-object: "? backup passphrase"

    local storageUsername; storageUsername="$(NODENV_VERSION=system bw get username "${storageBwItem}")" || fail
    local storageUri; storageUri="$(NODENV_VERSION=system bw get uri "${storageBwItem}")" || fail
    local storageHost; storageHost="$(echo "${storageUri}" | cut -d ":" -f 1)" || fail
    local storagePort; storagePort="$(echo "${storageUri}" | cut -d ":" -f 2)" || fail
    local passphrase; passphrase="$(NODENV_VERSION=system bw get password "${passphraseBwItem}")" || fail

    ssh::add-host-to-known-hosts "${storageHost}" "${storagePort}" || fail

    builtin printf "export BACKUP_NAME=$(printf "%q" "${backupName}")\nexport STORAGE_USERNAME=$(printf "%q" "${storageUsername}")\nexport STORAGE_HOST=$(printf "%q" "${storageHost}")\nexport STORAGE_PORT=$(printf "%q" "${storagePort}")\nexport BORG_REPO=$(printf "%q" "ssh://${storageUsername}@${storageUri}/./${backupPath}")\nexport BORG_PASSPHRASE=$(printf "%q" "${passphrase}")\n" | (umask 077 && tee "${credentialsFile}" >/dev/null) || fail
  fi
}

borg::load-backup-credentials() {
  local backupName="$1"
  local credentialsFile="${HOME}/.${backupName}.backup-credentials"

  . "${credentialsFile}" || fail
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

  if [ -f "${exportPath}.key" ] || [ -f "${exportPath}.key.html" ]; then
    fail "Key files are already present: ${exportPath}.*"
  fi

  borg key export "${BORG_REPO}" "${exportPath}.key" || fail
  borg key export --qr-html "${BORG_REPO}" "${exportPath}.key.html" || fail
}

borg::import-key() {
  local keyPath="${1:-}"

  if [ "${keyPath}" = "--paper" ]; then
    borg key import --paper "${BORG_REPO}" || fail
    return
  fi

  if [ -n "${keyPath}" ]; then
    if [ ! -f "${keyPath}" ]; then
      fail "Key file must be present: ${keyPath}"
    fi

    borg key import "${BORG_REPO}" "${keyPath}" || fail
    return
  fi

  if [ -t 0 ]; then
    local matchPath="${HOME}/${BACKUP_NAME}-"
    if ls "${matchPath}"*.key >/dev/null 2>&1; then
      files=("${matchPath}"*.key)
      menu::select-argument-and-run borg::import-key "${files[@]}" || fail
    else
      fail "Key path must be specified, or sutable files must be in the home directory"
    fi
  else
    fail "Key path must be specified"
  fi
}

borg::connect-sftp() {
  sftp -P "${STORAGE_PORT}" "${STORAGE_USERNAME}@${STORAGE_HOST}" || fail
}

borg::systemd::init-service() {
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

  systemctl --user reenable "${BACKUP_NAME}.service" || fail

  if systemctl --user is-enabled "${BACKUP_NAME}.timer" >/dev/null 2>&1; then
    borg::systemd::enable-timer || fail
  fi
}

borg::systemd::start-service() {
  systemctl --user --no-block start "${BACKUP_NAME}.service" || fail
}

borg::systemd::stop-service() {
  systemctl --user stop "${BACKUP_NAME}.service" || fail
}

borg::systemd::enable-timer() {
  local servicesPath="${HOME}/.config/systemd/user"
  mkdir -p "${servicesPath}" || fail

  tee "${servicesPath}/${BACKUP_NAME}.timer" <<EOF || fail
[Unit]
Description=Backup service timer for ${BACKUP_NAME}

[Timer]
OnCalendar=hourly
RandomizedDelaySec=600

[Install]
WantedBy=timers.target
EOF

  systemctl --user reenable "${BACKUP_NAME}.timer" || fail
  systemctl --user start "${BACKUP_NAME}.timer" || fail
}

borg::systemd::disable-timer() {
  systemctl --user disable "${BACKUP_NAME}.timer" || fail
}

borg::systemd::status() {
  systemctl --user status "${BACKUP_NAME}.service"
  echo ""
  systemctl --user status "${BACKUP_NAME}.timer"
  echo ""
  systemctl --user list-timers "${BACKUP_NAME}.timer" --all || fail
}

borg::systemd::log() {
  journalctl --user -u "${BACKUP_NAME}.service" --since today || fail
}
