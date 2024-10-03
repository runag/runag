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
set -o nounset

fail () 
{ 
    local exit_status;
    local unless_good=false;
    local perform_softfail=false;
    local trace_start=1;
    local message;
    while [ "$#" -gt 0 ]; do
        case "$1" in 
            -e | --exit-status)
                exit_status="$2";
                shift;
                shift
            ;;
            -u | --unless-good)
                unless_good=true;
                shift
            ;;
            -s | --soft)
                perform_softfail=true;
                shift
            ;;
            -w | --wrapped-softfail)
                perform_softfail=true;
                trace_start=2;
                shift
            ;;
            -*)
                { 
                    declare -F "log::error" > /dev/null && log::error "Unknown argument for fail: $1"
                } || echo "Unknown argument for fail: $1" 1>&2;
                shift;
                message="$*";
                break
            ;;
            *)
                message="$1";
                break
            ;;
        esac;
    done;
    if [ -z "${message:-}" ]; then
        message="Abnormal termination";
    fi;
    if ! [[ "${exit_status:-}" =~ ^[0-9]+$ ]]; then
        exit_status=1;
    else
        if [ "${exit_status:-}" = 0 ]; then
            if [ "${unless_good}" = true ]; then
                return 0;
            fi;
            exit_status=1;
        fi;
    fi;
    { 
        declare -F "log::error" > /dev/null && log::error "${message}"
    } || echo "${message}" 1>&2;
    local trace_line trace_index trace_end=$((${#BASH_LINENO[@]}-1));
    for ((trace_index=trace_start; trace_index<=trace_end; trace_index++))
    do
        trace_line="  ${BASH_SOURCE[${trace_index}]}:${BASH_LINENO[$((trace_index-1))]}: in \`${FUNCNAME[${trace_index}]}'";
        { 
            declare -F "log::error" > /dev/null && log::error "${trace_line}"
        } || echo "${trace_line}" 1>&2;
    done;
    if [ "${perform_softfail}" = true ]; then
        return "${exit_status:-0}";
    fi;
    exit "${exit_status:-0}"
}
softfail () 
{ 
    fail --wrapped-softfail "$@"
}
apt::install () 
{ 
    sudo DEBIAN_FRONTEND=noninteractive apt-get -y install "$@" || softfail || return $?
}
apt::update () 
{ 
    sudo DEBIAN_FRONTEND=noninteractive apt-get update || softfail || return $?
}
git::ensure_git_is_installed () 
{ 
    ( if [[ "${OSTYPE}" =~ ^linux ]]; then
        if ! command -v git > /dev/null; then
            . /etc/os-release || softfail || return $?;
            if [ "${ID:-}" = debian ] || [ "${ID_LIKE:-}" = debian ]; then
                apt::update || softfail || return $?;
                apt::install git || softfail || return $?;
            else
                if [ "${ID:-}" = arch ]; then
                    sudo pacman --sync --refresh --sysupgrade --noconfirm || softfail || return $?;
                    sudo pacman --sync --needed --noconfirm git || softfail || return $?;
                else
                    softfail "Unable to install git, unknown operating system" || return $?;
                fi;
            fi;
        fi;
    else
        if [[ "${OSTYPE}" =~ ^darwin ]]; then
            git --version > /dev/null || softfail "Please install git" || return $?;
        else
            if ! command -v git > /dev/null; then
                softfail "Unable to install git, unknown operating system" || return $?;
            fi;
        fi;
    fi )
}
git::clone_or_update_local_mirror () 
{ 
    local source_path="$1";
    local dest_path="$2";
    local remote_name="${3:-}";
    local source_path_full;
    source_path_full="$(cd "${source_path}" > /dev/null 2>&1 && pwd)" || fail;
    if [ ! -d "${dest_path}" ]; then
        git clone "${source_path}" "${dest_path}" || fail;
        local mirror_origin;
        mirror_origin="$(git -C "${source_path}" remote get-url origin)" || fail;
        git -C "${dest_path}" remote set-url origin "${mirror_origin}" || fail;
        if [ -n "${remote_name}" ]; then
            git -C "${dest_path}" remote add "${remote_name}" "${source_path_full}" || fail;
        fi;
    else
        git -C "${dest_path}" pull "${remote_name}" main || fail;
    fi
}
runag::offline_deploy_script () 
{ 
    ( if [ "${RUNAG_VERBOSE:-}" = true ]; then
        PS4='+${BASH_SUBSHELL} ${BASH_SOURCE:+"${BASH_SOURCE}:${LINENO}: "}${FUNCNAME[0]:+"in \`${FUNCNAME[0]}'"'"' "}** ';
        set -o xtrace;
    fi;
    git::ensure_git_is_installed || softfail || return $?;
    local install_path="${HOME}/.runag";
    if [ ! -d runag.git ]; then
        fail "Unable to find runag.git directory";
    fi;
    git::clone_or_update_local_mirror runag.git "${install_path}" "offline-install" || fail;
    local runagfile;
    for runagfile in runagfiles/*;
    do
        if [ -d "${runagfile}" ]; then
            git::clone_or_update_local_mirror "${runagfile}" "${install_path}/runagfiles/${runagfile}" "offline-install" || fail;
        fi;
    done;
    cd "${HOME}" || fail;
    "${install_path}"/bin/runag )
}
runag::offline_deploy_script "$@"
