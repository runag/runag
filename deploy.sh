#!/usr/bin/env bash

#  Copyright 2012-2022 Rùnag project contributors
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

# This script is wrapped inside a function with a random name to lower the chance for the bash
# to run some unexpected commands in case if "curl | bash" fails in the middle of download.
__xVhMyefCbBnZFUQtwqCs() {

fail () 
{ 
    local exit_status="";
    local unless_good=false;
    local perform_softfail=false;
    local trace_start=1;
    local message="";
    while [[ "$#" -gt 0 ]]; do
        case $1 in 
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
    if [ -z "${message}" ]; then
        message="Abnormal termination";
    fi;
    if ! [[ "${exit_status}" =~ ^[0-9]+$ ]]; then
        exit_status=1;
    else
        if [ "${exit_status}" = 0 ]; then
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
        return "${exit_status}";
    fi;
    exit "${exit_status}"
}
softfail () 
{ 
    fail --wrapped-softfail "$@"
}

deploy_script () 
{ 
    if [ -n "${1:-}" ]; then
        if declare -F "deploy_script::$1" > /dev/null; then
            "deploy_script::$1" "${@:2}";
            softfail --exit-status $? --unless-good || return $?;
        else
            softfail "deploy_script: command not found: $1";
            return $?;
        fi;
    fi
}
deploy_script::add () 
{ 
    runagfile::add "$1" || softfail || return $?;
    deploy_script "${@:2}";
    softfail --exit-status $? --unless-good
}
deploy_script::run () 
{ 
    "${HOME}/.runag/bin/runag" "$@";
    softfail --exit-status $? --unless-good
}

apt::install () 
{ 
    sudo DEBIAN_FRONTEND=noninteractive apt-get -y install "$@" || softfail || return $?
}
apt::update () 
{ 
    sudo DEBIAN_FRONTEND=noninteractive apt-get update || softfail || return $?
}

git::install_git () 
{ 
    if [[ "${OSTYPE}" =~ ^linux ]]; then
        if ! command -v git > /dev/null; then
            if command -v apt-get > /dev/null; then
                apt::update || softfail || return $?;
                apt::install git || softfail || return $?;
            else
                softfail "Unable to install git, apt-get not found" || return $?;
            fi;
        fi;
    else
        if [[ "${OSTYPE}" =~ ^darwin ]]; then
            git --version > /dev/null || softfail || return $?;
        fi;
    fi
}
git::place_up_to_date_clone () 
{ 
    local branch_name="";
    while [[ "$#" -gt 0 ]]; do
        case $1 in 
            -b | --branch)
                local branch_name="$2";
                shift;
                shift
            ;;
            -*)
                softfail "Unknown argument: $1" || return $?
            ;;
            *)
                break
            ;;
        esac;
    done;
    local remote_url="$1";
    local dest_path="$2";
    if [ -d "${dest_path}" ]; then
        local current_url;
        current_url="$(git -C "${dest_path}" config remote.origin.url)" || softfail || return $?;
        if [ "${current_url}" != "${remote_url}" ]; then
            git::remove_current_clone "${dest_path}" || softfail || return $?;
        fi;
    fi;
    if [ ! -d "${dest_path}" ]; then
        git clone "${remote_url}" "${dest_path}" || softfail "Unable to clone ${remote_url}" || return $?;
    fi;
    if [ -n "${branch_name}" ]; then
        git -C "${dest_path}" pull origin "${branch_name}" || softfail "Unable to pull branch ${branch_name}" || return $?;
        git -C "${dest_path}" checkout "${branch_name}" || softfail "Unable to git checkout ${branch_name}" || return $?;
    else
        git -C "${dest_path}" pull || softfail "Unable to pull in ${dest_path}" || return $?;
    fi
}
git::remove_current_clone () 
{ 
    local dest_path="$1";
    local dest_full_path;
    dest_full_path="$(cd "${dest_path}" >/dev/null 2>&1 && pwd)" || softfail || return $?;
    local dest_parent_dir;
    dest_parent_dir="$(dirname "${dest_full_path}")" || softfail || return $?;
    local dest_dir_name;
    dest_dir_name="$(basename "${dest_full_path}")" || softfail || return $?;
    local backup_path;
    backup_path="$(mktemp -u "${dest_parent_dir}/${dest_dir_name}-RUNAG-PREVIOUS-CLONE-XXXXXXXXXX")" || softfail || return $?;
    mv "${dest_full_path}" "${backup_path}" || softfail || return $?
}

runagfile::add () 
{ 
    local user_name;
    user_name="$(<<<"$1" cut -d "/" -f 1)" || softfail || return $?;
    local repo_name;
    repo_name="$(<<<"$1" cut -d "/" -f 2)" || softfail || return $?;
    git::place_up_to_date_clone "https://github.com/${user_name}/${repo_name}.git" "${HOME}/.runag/runagfiles/${repo_name}-${user_name}-github" || softfail || return $?
}

runag::deploy_sh_main () 
{ 
    if [ "${RUNAG_VERBOSE:-}" = true ]; then
        set -o xtrace;
    fi;
    set -o nounset;
    git::install_git || softfail || return $?;
    git::place_up_to_date_clone "${RUNAG_DIST_REPO}" "${HOME}/.runag" || softfail || return $?;
    deploy_script "$@";
    softfail --exit-status $? --unless-good
}

export RUNAG_DIST_REPO="${RUNAG_DIST_REPO:-https://github.com/runag/runag.git}"

runag::deploy_sh_main "$@"

}; __xVhMyefCbBnZFUQtwqCs "$@"
