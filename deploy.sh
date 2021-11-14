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

# Script is wrapped inside a function with a random name to lower the chance
# of "curl | bash" to run some unexpected command in case if script download fails in the middle.

__xVhMyefCbBnZFUQtwqCs() {

apt::install () 
{ 
    sudo DEBIAN_FRONTEND=noninteractive apt-get -y install "$@" || fail
}
apt::update () 
{ 
    SOPKA_APT_LAZY_UPDATE_HAPPENED=true;
    sudo DEBIAN_FRONTEND=noninteractive apt-get update || fail
}
deploy-script::add () 
{ 
    task::run-with-install-filter sopka::add-sopkafile "$1" || softfail || return $?;
    deploy-script "${@:2}";
    softfail-unless-good-code $?
}
deploy-script::run () 
{ 
    "${HOME}/.sopka/bin/sopka" "$@";
    softfail-unless-good-code $?
}
deploy-script () 
{ 
    if [ -n "${1:-}" ]; then
        if declare -f "deploy-script::$1" > /dev/null; then
            "deploy-script::$1" "${@:2}";
            softfail-unless-good-code $? || return $?;
        else
            softfail "Sopka deploy-script: command not found: $1";
            return $?;
        fi;
    fi
}
fail () 
{ 
    softfail::internal "$@";
    exit $?
}
git::install-git () 
{ 
    if [[ "${OSTYPE}" =~ ^linux ]]; then
        if ! command -v git > /dev/null; then
            if command -v apt-get > /dev/null; then
                apt::update || fail;
                apt::install git || fail;
            else
                fail "Unable to install git, apt-get not found";
            fi;
        fi;
    fi;
    git --version > /dev/null || fail
}
git::place-up-to-date-clone () 
{ 
    local url="$1";
    local dest="$2";
    local branch="${3:-}";
    if [ -d "${dest}" ]; then
        local currentUrl;
        currentUrl="$(git -C "${dest}" config remote.origin.url)" || fail;
        if [ "${currentUrl}" != "${url}" ]; then
            local destFullPath;
            destFullPath="$(cd "${dest}" >/dev/null 2>&1 && pwd)" || fail;
            local destParentDir;
            destParentDir="$(dirname "${destFullPath}")" || fail;
            local destDirName;
            destDirName="$(basename "${destFullPath}")" || fail;
            local packupPath;
            packupPath="$(mktemp -u "${destParentDir}/${destDirName}-SOPKA-PREVIOUS-CLONE-XXXXXXXXXX")" || fail;
            mv "${destFullPath}" "${packupPath}" || fail;
            git clone "${url}" "${dest}" || fail "Unable to git clone ${url} to ${dest}";
        fi;
        git -C "${dest}" pull || fail "Unable to git pull in ${dest}";
    else
        git clone "${url}" "${dest}" || fail "Unable to git clone ${url} to ${dest}";
    fi;
    if [ -n "${branch:-}" ]; then
        git -C "${dest}" checkout "${branch}" || fail "Unable to git checkout ${branch} in ${dest}";
    fi
}
log::error-trace () 
{ 
    local message="${1:-""}";
    local startTraceFrom="${2:-1}";
    if [ -n "${message}" ]; then
        log::error "${message}" || echo "Sopka: Unable to log error: ${message}" 1>&2;
    fi;
    local line i endAt=$((${#BASH_LINENO[@]}-1));
    for ((i=startTraceFrom; i<=endAt; i++))
    do
        line="${BASH_SOURCE[${i}]}:${BASH_LINENO[$((i-1))]}: in \`${FUNCNAME[${i}]}'";
        log::error "  ${line}" || echo "Sopka: Unable to log stack trace: ${line}" 1>&2;
    done
}
log::error () 
{ 
    local message="$1";
    log::with-color "${message}" 9 1>&2
}
log::notice () 
{ 
    local message="$1";
    log::with-color "${message}" 14
}
log::with-color () 
{ 
    local message="$1";
    local foregroundColor="$2";
    local backgroundColor="${3:-}";
    local colorSeq="" defaultColorSeq="";
    if [ -t 1 ]; then
        colorSeq="$(terminal::color "${foregroundColor}" "${backgroundColor:-}")" || echo "Sopka: Unable to get terminal sequence from tput ($?)" 1>&2;
        defaultColorSeq="$(terminal::default-color)" || echo "Sopka: Unable to get terminal sequence from tput ($?)" 1>&2;
    fi;
    echo "${colorSeq}${message}${defaultColorSeq}"
}
softfail-unless-good-code () 
{ 
    softfail-unless-good::internal "" "$1"
}
softfail-unless-good::internal () 
{ 
    local message="${1:-"Abnormal termination"}";
    local exitStatus="${2:-undefined}";
    if ! [[ "${exitStatus}" =~ ^[0-9]+$ ]]; then
        exitStatus=1;
    fi;
    if [ "${exitStatus}" != 0 ]; then
        log::error-trace "${message}" 3 || echo "Sopka: Unable to log error: ${message}" 1>&2;
    fi;
    return "${exitStatus}"
}
softfail::internal () 
{ 
    local message="${1:-"Abnormal termination"}";
    local exitStatus="${2:-undefined}";
    if ! [[ "${exitStatus}" =~ ^[0-9]+$ ]]; then
        exitStatus=1;
    fi;
    log::error-trace "${message}" 3 || echo "Sopka: Unable to log error: ${message}" 1>&2;
    if [ "${exitStatus}" != 0 ]; then
        return "${exitStatus}";
    fi;
    return 1
}
softfail () 
{ 
    softfail::internal "$@"
}
sopka::add-sopkafile () 
{ 
    local packageId="$1";
    local dest;
    dest="$(echo "${packageId}" | tr "/" "-")" || softfail || return $?;
    git::place-up-to-date-clone "https://github.com/${packageId}.git" "${HOME}/.sopka/sopkafiles/github-${dest}" || softfail || return $?
}
sopka::deploy-sh-main () 
{ 
    if [ "${SOPKA_VERBOSE:-}" = true ]; then
        set -o xtrace;
    fi;
    set -o nounset;
    task::run-with-install-filter git::install-git || softfail || return $?;
    task::run-with-install-filter git::place-up-to-date-clone "https://github.com/senotrusov/sopka.git" "${HOME}/.sopka" || softfail || return $?;
    deploy-script "$@";
    softfail-unless-good-code $?
}
task::complete-with-cleanup () 
{ 
    task::complete || softfail || return $?;
    if [ "${SOPKA_TASK_KEEP_TEMP_FILES:-}" != true ]; then
        rm -fd "${tempDir}/stdout" "${tempDir}/stderr" "${tempDir}" || softfail || return $?;
    fi
}
task::complete () 
{ 
    local errorState=0;
    local stderrPresent=false;
    if [ "${taskStatus:-1}" = 0 ] && [ -s "${tempDir}/stderr" ]; then
        stderrPresent=true;
        if [ -n "${SOPKA_TASK_STDERR_FILTER:-}" ] && task::is-stderr-empty-after-filtering "${tempDir}/stderr"; then
            stderrPresent=false;
        fi;
    fi;
    if [ "${taskStatus:-1}" != 0 ] || [ "${stderrPresent}" = true ] || [ "${SOPKA_VERBOSE:-}" = true ] || [ "${SOPKA_TASK_VERBOSE:-}" = true ]; then
        if [ -s "${tempDir}/stdout" ]; then
            cat "${tempDir}/stdout" || { 
                echo "Sopka: Unable to display task stdout ($?)" 1>&2;
                errorState=1
            };
        fi;
        if [ -s "${tempDir}/stderr" ]; then
            test -t 2 && terminal::color 9 1>&2;
            cat "${tempDir}/stderr" 1>&2 || { 
                echo "Sopka: Unable to display task stderr ($?)" 1>&2;
                errorState=2
            };
            test -t 2 && terminal::default-color 1>&2;
        fi;
    fi;
    if [ "${errorState}" != 0 ]; then
        softfail "task::cleanup error state ${errorState}" || return $?;
    fi
}
task::detect-fail-state () 
{ 
    local taskStatus="$3";
    if [ -z "${SOPKA_TASK_FAIL_DETECTOR:-}" ]; then
        return "${taskStatus}";
    fi;
    "${SOPKA_TASK_FAIL_DETECTOR}" "$@"
}
task::install-filter () 
{ 
    grep -vFx "Success." | grep -vFx "Warning: apt-key output should not be parsed (stdout is not a terminal)" | grep -vx "Cloning into '.*'\\.\\.\\.";
    if ! [[ "${PIPESTATUS[*]}" =~ ^([01][[:blank:]])*[01]$ ]]; then
        softfail || return $?;
    fi
}
task::is-stderr-empty-after-filtering () 
{ 
    local stderrFile="$1";
    local stderrSize;
    stderrSize="$("${SOPKA_TASK_STDERR_FILTER}" <"${stderrFile}" | awk NF | wc -c; test "${PIPESTATUS[*]}" = "0 0 0")" || softfail || return $?;
    if [ "${stderrSize}" != 0 ]; then
        return 1;
    fi
}
task::run-with-install-filter () 
{ 
    local SOPKA_TASK_STDERR_FILTER=task::install-filter;
    task::run "$@"
}
task::run () 
{ 
    ( if [ "${SOPKA_TASK_SSH_JUMP:-}" = true ]; then
        ssh::task "$@";
        return $?;
    fi;
    if [ "${SOPKA_TASK_OMIT_TITLE:-}" != true ]; then
        log::notice "Performing '${SOPKA_TASK_TITLE:-"$*"}'..." || fail;
    fi;
    local tempDir;
    tempDir="$(mktemp -d)" || fail;
    trap "task::complete-with-cleanup" EXIT;
    if [ -t 0 ]; then
        ( "$@" ) < /dev/null > "${tempDir}/stdout" 2> "${tempDir}/stderr";
    else
        ( "$@" ) > "${tempDir}/stdout" 2> "${tempDir}/stderr";
    fi;
    local taskStatus=$?;
    task::detect-fail-state "${tempDir}/stdout" "${tempDir}/stderr" "${taskStatus}";
    local taskStatus=$?;
    exit "${taskStatus}" )
}
terminal::color () 
{ 
    local foreground="$1";
    local background="${2:-}";
    local amount;
    if command -v tput > /dev/null && amount="$(tput colors 2>/dev/null)" && [[ "${amount}" =~ ^[0-9]+$ ]]; then
        if [[ "${foreground}" =~ ^[0-9]+$ ]] && [ "${amount}" -ge "${foreground}" ]; then
            tput setaf "${foreground}" || echo "Sopka: Unable to get terminal sequence from tput ($?)" 1>&2;
        fi;
        if [[ "${background}" =~ ^[0-9]+$ ]] && [ "${amount}" -ge "${background}" ]; then
            tput setab "${background}" || echo "Sopka: Unable to get terminal sequence from tput ($?)" 1>&2;
        fi;
    fi
}
terminal::default-color () 
{ 
    if command -v tput > /dev/null; then
        tput sgr 0 || echo "Sopka: Unable to get terminal sequence from tput ($?)" 1>&2;
    fi
}

sopka::deploy-sh-main "$@"

}; __xVhMyefCbBnZFUQtwqCs "$@"
