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
log::notice () 
{ 
    local message="$1";
    log::with-color "${message}" 11
}
log::error () 
{ 
    local message="$1";
    log::with-color "${message}" 9 1>&2
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
fail () 
{ 
    softfail::internal "$@";
    exit
}
softfail () 
{ 
    softfail::internal "$@"
}
softfail-unless-good-code () 
{ 
    softfail-unless-good::internal "" "$1"
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

# shellcheck disable=SC2030
task::run () 
{ 
    ( if [ "${SOPKA_TASK_OMIT_TITLE:-}" != true ]; then
        log::notice "Performing '${SOPKA_TASK_TITLE:-"$*"}'..." || fail;
    fi;
    local tmpFile;
    tmpFile="$(mktemp)" || fail;
    trap "task::cleanup" EXIT;
    if [ -t 0 ]; then
        ( "$@" ) < /dev/null > "${tmpFile}" 2> "${tmpFile}.stderr";
    else
        ( "$@" ) > "${tmpFile}" 2> "${tmpFile}.stderr";
    fi;
    local taskResult=$?;
    if [ $taskResult = 0 ] && [ "${SOPKA_TASK_FAIL_ON_ERROR_IN_RUBYGEMS:-}" = true ] && grep -q "^ERROR:" "${tmpFile}.stderr"; then
        taskResult=1;
    fi;
    exit $taskResult )
}
task::stderr-filter () 
{ 
    grep -vFx "Success." | grep -vFx "Warning: apt-key output should not be parsed (stdout is not a terminal)" | grep -vx "Cloning into '.*'\\.\\.\\." | grep -vx "Created symlink .* → .*\\." | awk NF;
    true
}
task::is-stderr-empty-after-filtering () 
{ 
    if declare -f "task::stderr-filter" > /dev/null; then
        task::stderr-filter | test "$(wc -c)" = 0;
        test "${PIPESTATUS[*]}" = "0 0";
    fi
}
# shellcheck disable=SC2031
task::cleanup () 
{ 
    local errorState=0;
    local stderrPresent=false;
    if [ -s "${tmpFile}.stderr" ]; then
        stderrPresent=true;
        if task::is-stderr-empty-after-filtering < "${tmpFile}.stderr"; then
            stderrPresent=false;
        fi;
    fi;
    if [ "${taskResult:-1}" != 0 ] || [ "${stderrPresent}" = true ] || [ "${SOPKA_VERBOSE:-}" = true ] || [ "${SOPKA_VERBOSE_TASKS:-}" = true ]; then
        cat "${tmpFile}" || { 
            echo "Sopka: Unable to display task stdout ($?)" 1>&2;
            errorState=1
        };
        if [ -s "${tmpFile}.stderr" ]; then
            test -t 2 && terminal::color 9 1>&2;
            cat "${tmpFile}.stderr" 1>&2 || { 
                echo "Sopka: Unable to display task stderr ($?)" 1>&2;
                errorState=2
            };
            test -t 2 && terminal::default-color 1>&2;
        fi;
    fi;
    if [ "${errorState}" != 0 ]; then
        fail "task::cleanup error state ${errorState}";
    fi;
    rm "${tmpFile}" || fail;
    rm -f "${tmpFile}.stderr" || fail
}

# shellcheck disable=SC2034
apt::update () 
{ 
    SOPKA_APT_LAZY_UPDATE_HAPPENED=true;
    sudo apt-get update || fail
}
apt::install () 
{ 
    sudo apt-get -y install "$@" || fail
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

sopka::add-sopkafile () 
{ 
    local packageId="$1";
    local dest;
    dest="$(echo "${packageId}" | tr "/" "-")" || softfail || return;
    git::place-up-to-date-clone "https://github.com/${packageId}.git" "${HOME}/.sopka/sopkafiles/github-${dest}" || softfail || return
}
deploy-script () 
{ 
    if [ -n "${1:-}" ]; then
        if declare -f "deploy-script::$1" > /dev/null; then
            "deploy-script::$1" "${@:2}";
            softfail-unless-good-code $? || return;
        else
            softfail "Sopka deploy-script: command not found: $1";
            return;
        fi;
    fi
}
deploy-script::add () 
{ 
    task::run sopka::add-sopkafile "$1" || softfail || return;
    deploy-script "${@:2}";
    softfail-unless-good-code $?
}
deploy-script::run () 
{ 
    "${HOME}/.sopka/bin/sopka" "$@";
    softfail-unless-good-code $?
}

if [ "${SOPKA_VERBOSE:-}" = true ]; then
  set -o xtrace
fi
set -o nounset

task::run git::install-git || softfail || return

task::run git::place-up-to-date-clone "https://github.com/senotrusov/sopka.git" "${HOME}/.sopka" || softfail || return

deploy-script "$@"
softfail-unless-good-code $?

}; __xVhMyefCbBnZFUQtwqCs "$@"
