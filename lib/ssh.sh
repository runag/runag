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

sshd::disable-password-authentication() {
  dir::sudo-make-if-not-exists /etc/ssh 755 || fail
  dir::sudo-make-if-not-exists /etc/ssh/sshd_config.d 755 || fail
  echo "PasswordAuthentication no" | file::sudo-write /etc/ssh/sshd_config.d/disable-password-authentication.conf || fail
}

ssh::import-id() {
  local publicUserId="$1"
  local userName="${2:-"${USER}"}"

  local userHome; userHome="$(linux::get-user-home "${userName}")" || fail
  local authorizedKeys="${userHome}/.ssh/authorized_keys"

  if [ "${userName}" != "${USER}" ]; then
    dir::sudo-make-if-not-exists-and-set-permissions "${userHome}/.ssh" 700 "${userName}" "${userName}" || fail
  else
    dir::make-if-not-exists-and-set-permissions "${userHome}/.ssh" 700 || fail
  fi

  ssh-import-id --output "${authorizedKeys}" "${publicUserId}" || fail

  if [ "${userName}" != "${USER}" ]; then
    sudo chown "${userName}"."${userName}" "${authorizedKeys}" || fail
  fi
}

ssh::make-user-config-dir-if-not-exists() {
  dir::make-if-not-exists "${HOME}/.ssh" 700 || fail
}

ssh::get-user-public-key() {
  local fileName="${1:-"id_ed25519"}"
  if [ -r "${HOME}/.ssh/${fileName}.pub" ]; then
    cat "${HOME}/.ssh/${fileName}.pub" || fail
  else
    fail "Unable to find user public key"
  fi
}

ssh::gnome-keyring-credentials::exists() {
  local keyFile="${1:-"id_ed25519"}"

  local keyFilePath="${HOME}/.ssh/${keyFile}"

  secret-tool lookup unique "ssh-store:${keyFilePath}" >/dev/null
}

ssh::gnome-keyring-credentials::save() {
  local password="$1"
  local keyFile="${2:-"id_ed25519"}"

  local keyFilePath="${HOME}/.ssh/${keyFile}"

  echo -n "${password}" | secret-tool store --label="Unlock password for: ${keyFilePath}" unique "ssh-store:${keyFilePath}"
  test "${PIPESTATUS[*]}" = "0 0" || fail
}

ssh::macos-keychain::exists() {
  local keyFile="${1:-"id_ed25519"}"

  local keyFilePath="${HOME}/.ssh/${keyFile}"

  ssh-add -L | grep -qF "${keyFilePath}"
}

ssh::macos-keychain::save() {
  local password="$1"
  local keyFile="${2:-"id_ed25519"}"

  local keyFilePath="${HOME}/.ssh/${keyFile}"

  local tempFile; tempFile="$(mktemp)" || fail
  chmod 755 "${tempFile}" || fail
  printf "#!/bin/sh\nexec cat\n" >"${tempFile}" || fail

  echo "${password}" | SSH_ASKPASS="${tempFile}" DISPLAY=1 ssh-add -K "${keyFilePath}"
  test "${PIPESTATUS[*]}" = "0 0" || fail

  rm "${tempFile}" || fail
}

ssh::macos-keychain::configure-use-on-all-hosts() {
  local sshConfigFile="${HOME}/.ssh/config"

  if [ ! -f "${sshConfigFile}" ]; then
    touch "${sshConfigFile}" || fail
  fi

  if ! grep -q "^# Use keychain" "${sshConfigFile}"; then
tee -a "${sshConfigFile}" <<EOF || fail "Unable to append to the file: ${sshConfigFile}"

# Use keychain
Host *
  UseKeychain yes
  AddKeysToAgent yes
EOF
  fi
}

ssh::wait-for-host-ssh-to-become-available() {
  local ip="$1"
  while true; do
    # note that here I omit "|| fail" for a reason, ssh-keyscan will fail if host is not yet there
    local key; key="$(ssh-keyscan "${ip}" 2>/dev/null)"
    if [ -n "${key}" ]; then
      return 0
    else
      if [ -t 2 ]; then
        echo "Waiting for SSH to become available on host '${ip}'..." >&2
      fi
      sleep 1 || fail
    fi
  done
}

ssh::refresh-host-in-known-hosts() {
  local hostName="$1"
  ssh::remove-host-from-known-hosts "${hostName}" || fail
  ssh::wait-for-host-ssh-to-become-available "${hostName}" || fail
  ssh::add-host-to-known-hosts "${hostName}" || fail
}

ssh::add-host-to-known-hosts() {
  local hostName="${1:-"${REMOTE_HOST}"}"
  local sshPort="${2:-"${REMOTE_PORT:-"22"}"}"
  local knownHosts="${HOME}/.ssh/known_hosts"

  if ! command -v ssh-keygen >/dev/null; then
    fail "ssh-keygen not found"
  fi

  if [ ! -f "${knownHosts}" ]; then
    ssh::make-user-config-dir-if-not-exists || fail
    (umask 133 && touch "${knownHosts}") || fail
  fi

  if [ "${sshPort}" = "22" ]; then
    local keygenHostString="${hostName}"
  else
    local keygenHostString="[${hostName}]:${sshPort}"
  fi

  if ! ssh-keygen -F "${keygenHostString}" >/dev/null; then
    ssh-keyscan -p "${sshPort}" -T 120 "${hostName}" >> "${knownHosts}" || fail
  fi
}

ssh::remove-host-from-known-hosts() {
  local hostName="$1"
  ssh-keygen -R "${hostName}" || fail
}

ssh::set-args() {
  # Please note: sshArgs variable is not function-local for this function

  if ! [[ "${OSTYPE}" =~ ^msys ]] && [ "${REMOTE_CONTROL_MASTER:-}" != "no" ]; then
    sshArgs+=("-o" "ControlMaster=${REMOTE_CONTROL_MASTER:-"auto"}")
    sshArgs+=("-S" "${REMOTE_CONTROL_PATH:-"${HOME}/.ssh/control-socket.%C"}")
    sshArgs+=("-o" "ControlPersist=${REMOTE_CONTROL_PERSIST:-"600"}")
  fi

  if [ -n "${REMOTE_IDENTITY_FILE:-}" ]; then
    sshArgs+=("-i" "${REMOTE_IDENTITY_FILE}")
  fi

  if [ -n "${REMOTE_PORT:-}" ]; then
    sshArgs+=("-p" "${REMOTE_PORT}")
  fi

  if [ "${REMOTE_SERVER_ALIVE_INTERVAL:-}" != "no" ]; then
    # the idea of 20 seconds is from https://datatracker.ietf.org/doc/html/rfc3948
    sshArgs+=("-o" "ServerAliveInterval=${REMOTE_SERVER_ALIVE_INTERVAL:-"20"}")
  fi

  if [ -n "${REMOTE_USER:-}" ]; then
    sshArgs+=("-l" "${REMOTE_USER}")
  fi

  if declare -p REMOTE_SSH_ARGS >/dev/null 2>&1; then
    sshArgs=("${sshArgs[@]}" "${REMOTE_SSH_ARGS[@]}")
  fi
}

ssh::shell-options() {
  if shopt -o -q xtrace || [ "${SOPKA_VERBOSE:-}" = true ]; then
    echo "set -o xtrace"
  fi

  if shopt -o -q nounset; then
    echo "set -o nounset"
  fi
}

ssh::remote-env::base-list() {
  echo "SOPKA_UPDATE_SECRETS SOPKA_TASK_VERBOSE SOPKA_VERBOSE"
}

ssh::remote-env() {
  local baseList; baseList="$(ssh::remote-env::base-list)" || softfail || return $?

  local list; IFS=" " read -r -a list <<< "${REMOTE_ENV:-} ${baseList}" || softfail || return $?

  local item; for item in "${list[@]}"; do
    if [ -n "${!item:-}" ]; then
      echo "export $(printf "%q=%q" "${item}" "${!item}")"
    fi
  done
}

ssh::script() {
  local joinedCommand="$*" # I don't want to save/restore IFS to be able to do "test -n "${*..."
  test -n "${joinedCommand//[[:blank:][:cntrl:]]/}" || softfail "Command should be specified" || return $?

  ssh::shell-options || softfail "Unable to produce shell-options" || return $?
  ssh::remote-env || softfail "Unable to produce remote-env" || return $?

  declare -f || softfail "Unable to produce source code dump of functions" || return $?

  if [ -n "${REMOTE_DIR:-}" ]; then
    printf "cd %q || exit \$?\n" "${REMOTE_DIR}"
  fi

  if [ -n "${REMOTE_UMASK:-}" ]; then
    printf "umask %q || exit \$?\n" "${REMOTE_UMASK}"
  fi

  local commandString; printf -v commandString " %q" "$@" || softfail "Unable to produce command string" || return $?
  echo "${commandString:1}"
}

ssh::remove-temp-files() {
  local exitStatus="${1:-0}"

  if [ "${SOPKA_TASK_KEEP_TEMP_FILES:-}" != true ] && [ -n "${tempDir:-}" ]; then
    rm -fd "${tempDir}/script" "${tempDir}/stdin" "${tempDir}/stdout" "${tempDir}/stderr" "${tempDir}" || softfail "Unable to remote temp files" || return $?
  fi

  return "${exitStatus}"
}

ssh::before-run() {
  # Please note: tempDir, scriptChecksum, and remoteTempDir variables are not function-local for this function

  if [ -z "${REMOTE_HOST:-}" ]; then
    softfail "REMOTE_HOST should be set" || return $?
  fi

  ssh::make-user-config-dir-if-not-exists || softfail "Unable to create ssh user config directory" || return $?

  ssh::set-args || softfail "Unable to set ssh args" || return $?

  tempDir="$(mktemp -d)" || softfail "Unable to make temp file" || return $?

  ssh::script "$@" >"${tempDir}/script" || softfail "Unable to produce script" || return $?

  scriptChecksum="$(cksum <"${tempDir}/script")" || softfail "Unable to calculate script checksum" || return $?

  # shellcheck disable=2029,2016
  remoteTempDir="$(ssh "${sshArgs[@]}" "${REMOTE_HOST}" "$(printf "sh -c %q" "$(printf 'tempDir="$(mktemp -d)" && cat>"${tempDir}/script" && { if [ "$(cksum <"${tempDir}/script")" != %q ]; then exit 254; fi; } && echo "${tempDir}"' "${scriptChecksum}")")" <"${tempDir}/script")" || softfail "Unable to put script to remote" $? || return $?

  if [ -z "${remoteTempDir}" ]; then
    softfail "Unable to get remote temp file name" || return $?
  fi
}

ssh::run() {
  local sshArgs=() tempDir scriptChecksum remoteTempDir

  ssh::before-run "$@" || softfail "Unable to perform ssh::before-run" $? || ssh::remove-temp-files $? || return $?

  # shellcheck disable=2029,2016
  ssh "${sshArgs[@]}" "${REMOTE_HOST}" "$(printf "sh -c %q" "$(printf 'tempDir=%q; bash "${tempDir}/script"; scriptStatus=$?; rm -fd "${tempDir}/script" "${tempDir}"; exit "${scriptStatus}"' "${remoteTempDir}")")"

  local sshResult=$?

  # On error here, we don't alter ssh command exit status
  ssh::remove-temp-files || softfail "Unable to remove temp files"

  return "${sshResult}"
}

ssh::task-with-install-filter() {
  # shellcheck disable=2034
  local SOPKA_TASK_STDERR_FILTER=task::install-filter
  ssh::task "$@"
}

ssh::task-with-rubygems-fail-detector() {
  # shellcheck disable=2034
  local SOPKA_TASK_FAIL_DETECTOR=task::rubygems-fail-detector
  ssh::task "$@"
}

ssh::task-without-title() {
  # shellcheck disable=2034
  local SOPKA_TASK_OMIT_TITLE=true
  ssh::task "$@"
}

ssh::task-with-title() {
  # shellcheck disable=2034
  local SOPKA_TASK_TITLE="$1"
  ssh::task "${@:2}"
}

ssh::task-with-short-title() {
  # shellcheck disable=2034
  local SOPKA_TASK_TITLE="$1"
  ssh::task "$@"
}

ssh::task-verbose() {
  # shellcheck disable=2034
  local SOPKA_TASK_VERBOSE=true
  ssh::task "$@"
}

ssh::call() {
  # shellcheck disable=2034
  local SOPKA_TASK_VERBOSE=true SOPKA_TASK_OMIT_TITLE=true
  ssh::task "$@"
}

ssh::call-with-remote-temp-copy() {
  # shellcheck disable=2034
  local SOPKA_TASK_VERBOSE=true SOPKA_TASK_OMIT_TITLE=true
  ssh::task-with-remote-temp-copy "$@"
}

ssh::task-with-remote-temp-copy() {
  local localDir="$1"

  if [ ! -e "${localDir}" ]; then
    softfail "File does not exists: ${localDir}"
    return $?
  fi

  if [ -d "${localDir}" ]; then
    local rsyncSrc="${localDir}/"
    local rsyncDest; rsyncDest="$(ssh::call mktemp -d)" || softfail "Unable to create remote temp directory" || return $?
  else
    local rsyncSrc="${localDir}"
    local rsyncDest; rsyncDest="$(ssh::call mktemp)" || softfail "Unable to create remote temp file" || return $?
  fi

  rsync::sync-to-remote "${rsyncSrc}" "${rsyncDest}" || softfail "Unable to rsync to remote" || return $?

  ssh::task "$2" "${rsyncDest}" "${@:3}"
  local taskResult=$?

  ssh::call rm -rf "${rsyncDest}" || softfail "Unable to remove remote temp file"

  return "${taskResult}"
}

ssh::task::softfail(){
  # Please note: tempDir and remoteTempDir variables are not function-local for this function
  local message="$1"
  softfail "${message}${tempDir:+". Local task: ${tempDir}."}${remoteTempDir:+". Remote task: ${remoteTempDir}"}" "${@:2}"
}

ssh::task::invoke(){
  ssh::task::raw-invoke "$@" || ssh::task::softfail "ssh::task::raw-invoke call failed" $? || return $?
}

ssh::task::quiet-on-ssh-errors-invoke(){
  local errorMessage="$1"

  ssh::task::raw-invoke "${@:2}"

  local invokeStatus=$?

  if [ "${invokeStatus}" = 255 ]; then
    return 255
  fi

  if [ "${invokeStatus}" != 0 ]; then
    ssh::task::softfail "${errorMessage}" "${invokeStatus}"
    return "${invokeStatus}"
  fi
}

ssh::task::raw-invoke(){
  # Please note: remoteTempDir variable is not function-local for this function
  # shellcheck disable=2029
  ssh "${sshArgs[@]}" "${REMOTE_HOST}" "$(printf "sh -c %q" "$(printf "tempDir=%q; $1" "${remoteTempDir}" "${@:2}")")"
}

ssh::task::nohup-raw-invoke(){
  # Keep an eye on this
  # Bug 396 - sshd orphans processes when no pty allocated
  # https://bugzilla.mindrot.org/show_bug.cgi?id=396

  # shellcheck disable=2029
  ssh "${sshArgs[@]}" "${REMOTE_HOST}" "$(printf "sh -c %q" "$(printf "nohup sh -c %q >/dev/null 2>/dev/null </dev/null" "$(printf "tempDir=%q; $1" "${remoteTempDir}" "${@:2}")")")"
}

ssh::task::information-message(){
  local message="$1"
  if [ -t 2 ]; then
    test -t 2 && terminal::color 12 >&2
    echo "${message}" >&2
    test -t 2 && terminal::default-color >&2
  fi
}

# shellcheck disable=2016
ssh::task() {
  local sshArgs=() tempDir scriptChecksum remoteTempDir informationMessageState

  if [ "${SOPKA_TASK_OMIT_TITLE:-}" != true ]; then
    log::notice "Performing '${SOPKA_TASK_TITLE:-"$*"}'..." || ssh::task::softfail "Unable to display title" || return $?
  fi

  ssh::before-run "$@" || ssh::task::softfail "Unable to perform ssh::before-run" $? || ssh::remove-temp-files $? || return $?

  local remoteStdin="/dev/null"
  if [ ! -t 0 ]; then
    ssh::task::store-stdin || ssh::task::softfail "Unable to store stdin data" $? || ssh::remove-temp-files $? || return $?
  fi

  ssh::task::nohup-raw-invoke 'bash "${tempDir}/script" <%q >"${tempDir}/stdout" 2>"${tempDir}/stderr"; scriptStatus=$?; echo "${scriptStatus}" >"${tempDir}/exitStatus"; touch "${tempDir}/done"; exit "${scriptStatus}"' "${remoteStdin}"
  local taskStatus=$?

  if [ "${taskStatus}" = 255 ]; then
    ssh::task::information-message "Transport error getting the command exit status, attempting to reconnect..."
  fi

  local maxRetries="${SOPKA_TASK_RECONNECT_ATTEMPTS:-120}"
  local i; for ((i=1; i<=maxRetries; i++)); do

    ssh::task::get-result

    local getResultResult=$?
    if [ "${getResultResult}" != 255 ]; then
      break
    fi

    if [ "${informationMessageState}" = done_flag_absent ]; then
      ssh::task::information-message "Command is probably still running, retrying (${i} of ${maxRetries})..."
    else
      ssh::task::information-message "Transport error getting the command result, retrying (${i} of ${maxRetries})..."
    fi

    informationMessageState=clean_state
    sleep "${SOPKA_TASK_RECONNECT_DELAY:-5}"
  done

  if [ "${getResultResult}" = 255 ]; then
    ssh::task::softfail "Maximum retry limit reached getting the task result back"
    ssh::remove-temp-files || softfail "Unable to remove temp files"
    return "${getResultResult}"
  fi

  if [ "${getResultResult}" != 0 ]; then
    ssh::task::softfail "Unable to get task result"
    ssh::remove-temp-files || softfail "Unable to remove temp files"
    return "${getResultResult}"
  fi

  task::detect-fail-state "${tempDir}/stdout" "${tempDir}/stderr" "${taskStatus}"
  taskStatus=$?

  task::complete || ssh::task::softfail "Unable to perform task::complete" || ssh::remove-temp-files $? || return $?

  # Note, that after that point we don't return any exit status other than taskStatus
  if [ "${SOPKA_TASK_KEEP_TEMP_FILES:-}" != true ]; then
    ssh::task::invoke 'rm -fd "${tempDir}/script" "${tempDir}/stdin" "${tempDir}/stdout" "${tempDir}/stderr" "${tempDir}/output-concat-good" "${tempDir}/exitStatus" "${tempDir}/done" "${tempDir}"' || ssh::task::softfail "Unable to remove remote temp files"

    ssh::remove-temp-files || ssh::task::softfail "Unable to remove temp files"
  fi

  return "${taskStatus}"
}

# shellcheck disable=2016
ssh::task::store-stdin() {
  # Please note: tempDir, remoteTempDir, and remoteStdin variables are not function-local for this function

  cat >"${tempDir}/stdin" || ssh::task::softfail "Unable to read stdin" || return $?

  if [ -s "${tempDir}/stdin" ]; then
    local stdinChecksum; stdinChecksum="$(cksum <"${tempDir}/stdin")" || ssh::task::softfail "Unable to get stdin checksum" || return $?

    ssh::task::invoke 'cat >"${tempDir}/stdin"; if [ "$(cksum <"${tempDir}/stdin")" != %q ]; then exit 254; fi' "${stdinChecksum}" <"${tempDir}/stdin" || ssh::task::softfail "Unable to store stdin data on remote" $? || return $?

    remoteStdin="${remoteTempDir}/stdin"
  fi
}

# shellcheck disable=2016
ssh::task::get-result(){
  # Please note: taskStatus and tempDir variables are not function-local for this function

  if [ "${taskStatus}" = 255 ]; then
    if ! ssh::task::raw-invoke 'test -f "${tempDir}/done"'; then
      informationMessageState=done_flag_absent

      ssh::task::quiet-on-ssh-errors-invoke "Unable to find remote task state directory, remote host may have been rebooted" 'test -d "${tempDir}"' || return $?
      ssh::task::quiet-on-ssh-errors-invoke "It seems that the remote command did not even start" 'test -f "${tempDir}/stdout"' || return $?

      return 255
    fi

    local retrievedTaskStatus
    retrievedTaskStatus="$(ssh::task::quiet-on-ssh-errors-invoke "Unable to get exit status from remote" 'cat "${tempDir}/exitStatus"')" || return $?

    if [[ "${retrievedTaskStatus}" =~ ^[0-9]+$ ]]; then
      taskStatus="${retrievedTaskStatus}"
    else
      taskStatus=1
    fi
  fi

  ssh::task::quiet-on-ssh-errors-invoke "Unable to get stdout from remote" 'cat "${tempDir}/stdout"' >"${tempDir}/stdout" || return $?
  ssh::task::quiet-on-ssh-errors-invoke "Unable to get stderr from remote" 'cat "${tempDir}/stderr"' >"${tempDir}/stderr" || return $?

  local remoteChecksum localChecksum

  # there is no PIPESTATUS in posix shell
  remoteChecksum="$(ssh::task::quiet-on-ssh-errors-invoke "Unable to get remote output checksum" '{ cat "${tempDir}/stdout" "${tempDir}/stderr" && touch "${tempDir}/output-concat-good"; } | cksum && test -f "${tempDir}/output-concat-good"')" || return $?

  localChecksum="$(cat "${tempDir}/stdout" "${tempDir}/stderr" | cksum; test "${PIPESTATUS[*]}" = "0 0")" || ssh::task::softfail "Unable to get local output checksum" || return $?

  if [ "${remoteChecksum}" != "${localChecksum}" ]; then
    ssh::task::softfail "Output checksum mismatch"
    return 1
  fi
}
