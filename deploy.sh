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

# This script is wrapped inside a function with a random name to lower the chance for the bash
# to run some unexpected commands in case if "curl | bash" fails in the middle of download.
__xVhMyefCbBnZFUQtwqCs() {
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
                    softfail "Unable to install git, your operating system is not supported" || return $?;
                fi;
            fi;
        fi;
    else
        if [[ "${OSTYPE}" =~ ^darwin ]]; then
            git --version > /dev/null || softfail "Please install git" || return $?;
        else
            if ! command -v git > /dev/null; then
                softfail "Unable to install git, your operating system is not supported" || return $?;
            fi;
        fi;
    fi )
}
git::place_up_to_date_clone () 
{ 
    local branch_name;
    while [ "$#" -gt 0 ]; do
        case "$1" in 
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
        current_url="$(cd "${dest_path}" && git config remote.origin.url)" || softfail || return $?;
        if [ "${current_url}" != "${remote_url}" ]; then
            git::remove_current_clone "${dest_path}" || softfail || return $?;
        fi;
    fi;
    if [ ! -d "${dest_path}" ]; then
        git clone "${remote_url}" "${dest_path}" || softfail "Unable to clone ${remote_url}" || return $?;
    fi;
    if [ -n "${branch_name:-}" ]; then
        ( cd "${dest_path}" && git remote update ) || softfail "Unable to perform git remote update: ${dest_path}" || return $?;
        ( cd "${dest_path}" && git fetch ) || softfail "Unable to perform git fetch: ${dest_path}" || return $?;
        ( cd "${dest_path}" && git checkout "${branch_name}" ) || softfail "Unable to perform git checkout: ${dest_path}" || return $?;
    else
        ( cd "${dest_path}" && git pull ) || softfail "Unable to perform git pull: ${dest_path}" || return $?;
    fi
}
git::remove_current_clone () 
{ 
    local dest_path="$1";
    local dest_full_path;
    dest_full_path="$(cd "${dest_path}" > /dev/null 2>&1 && pwd)" || softfail || return $?;
    local dest_parent_dir;
    dest_parent_dir="$(dirname "${dest_full_path}")" || softfail || return $?;
    local dest_dir_name;
    dest_dir_name="$(basename "${dest_full_path}")" || softfail || return $?;
    local backup_path;
    backup_path="$(mktemp -u "${dest_parent_dir}/${dest_dir_name}-PREVIOUS-CLONE-XXXXXXXXXX")" || softfail || return $?;
    mv "${dest_full_path}" "${backup_path}" || softfail || return $?
}
runagfile::add () 
{ 
    local user_name;
    user_name="$(cut -d "/" -f 1 <<< "$1")" || softfail || return $?;
    local repo_name;
    repo_name="$(cut -d "/" -f 2 <<< "$1")" || softfail || return $?;
    git::place_up_to_date_clone "https://github.com/${user_name}/${repo_name}.git" "${HOME}/.runag/runagfiles/${repo_name}-${user_name}-github" || softfail || return $?
}
runag::online_deploy_script () 
{ 
    if [ "${RUNAG_VERBOSE:-}" = true ]; then
        PS4='+${BASH_SUBSHELL} ${BASH_SOURCE:+"${BASH_SOURCE}:${LINENO}: "}${FUNCNAME[0]:+"in \`${FUNCNAME[0]}'"'"' "}** ';
        set -o xtrace;
    fi;
    git::ensure_git_is_installed || softfail || return $?;
    git::place_up_to_date_clone "${RUNAG_DIST_REPO}" "${HOME}/.runag" || softfail || return $?;
    while [ "$#" -gt 0 ]; do
        case "$1" in 
            add)
                runagfile::add "$2" || softfail || return $?;
                shift;
                shift
            ;;
            run)
                shift;
                "${HOME}/.runag/bin/runag" "$@" || softfail || return $?;
                break
            ;;
            *)
                softfail "runag::online_deploy_script: command not found: $*" || return $?
            ;;
        esac;
    done
}
export RUNAG_DIST_REPO="${RUNAG_DIST_REPO:-https://github.com/runag/runag.git}"
runag::online_deploy_script "$@"
}; __xVhMyefCbBnZFUQtwqCs "$@"
