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
deploy_script::add () 
{ 
    task::run_with_install_filter sopka::add_sopkafile "$1" || softfail || return $?;
    deploy_script "${@:2}";
    softfail_unless_good_code $?
}
deploy_script::run () 
{ 
    "${HOME}/.sopka/bin/sopka" "$@";
    softfail_unless_good_code $?
}
deploy_script () 
{ 
    if [ -n "${1:-}" ]; then
        if declare -f "deploy_script::$1" > /dev/null; then
            "deploy_script::$1" "${@:2}";
            softfail_unless_good_code $? || return $?;
        else
            softfail "Sopka deploy_script: command not found: $1";
            return $?;
        fi;
    fi
}
fail () 
{ 
    softfail::internal "$@";
    exit $?
}
git::install_git () 
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
git::place_up_to_date_clone () 
{ 
    local url="$1";
    local dest="$2";
    local branch="${3:-}";
    if [ -d "${dest}" ]; then
        local current_url;
        current_url="$(git -C "${dest}" config remote.origin.url)" || fail;
        if [ "${current_url}" != "${url}" ]; then
            local dest_full_path;
            dest_full_path="$(cd "${dest}" >/dev/null 2>&1 && pwd)" || fail;
            local dest_parent_dir;
            dest_parent_dir="$(dirname "${dest_full_path}")" || fail;
            local dest_dir_name;
            dest_dir_name="$(basename "${dest_full_path}")" || fail;
            local backup_path;
            backup_path="$(mktemp -u "${dest_parent_dir}/${dest_dir_name}-SOPKA-PREVIOUS-CLONE-XXXXXXXXXX")" || fail;
            mv "${dest_full_path}" "${backup_path}" || fail;
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
log::error_trace () 
{ 
    local message="${1:-""}";
    local start_trace_from="${2:-1}";
    if [ -n "${message}" ]; then
        log::error "${message}" || echo "Sopka: Unable to log error: ${message}" 1>&2;
    fi;
    local line i end_at=$((${#BASH_LINENO[@]}-1));
    for ((i=start_trace_from; i<=end_at; i++))
    do
        line="${BASH_SOURCE[${i}]}:${BASH_LINENO[$((i-1))]}: in \`${FUNCNAME[${i}]}'";
        log::error "  ${line}" || echo "Sopka: Unable to log stack trace: ${line}" 1>&2;
    done
}
log::error () 
{ 
    local message="$1";
    log::with_color "${message}" 9 1>&2
}
log::notice () 
{ 
    local message="$1";
    log::with_color "${message}" 14
}
log::with_color () 
{ 
    local message="$1";
    local foreground_color="$2";
    local background_color="${3:-}";
    local color_seq="" default_color_seq="";
    if [ -t 1 ]; then
        color_seq="$(terminal::color "${foreground_color}" "${background_color:-}")" || echo "Sopka: Unable to get terminal sequence from tput ($?)" 1>&2;
        default_color_seq="$(terminal::default_color)" || echo "Sopka: Unable to get terminal sequence from tput ($?)" 1>&2;
    fi;
    echo "${color_seq}${message}${default_color_seq}"
}
softfail_unless_good_code () 
{ 
    softfail_unless_good::internal "" "$1"
}
softfail_unless_good::internal () 
{ 
    local message="${1:-"Abnormal termination"}";
    local exit_status="${2:-undefined}";
    if ! [[ "${exit_status}" =~ ^[0-9]+$ ]]; then
        exit_status=1;
    fi;
    if [ "${exit_status}" != 0 ]; then
        log::error_trace "${message}" 3 || echo "Sopka: Unable to log error: ${message}" 1>&2;
    fi;
    return "${exit_status}"
}
softfail::internal () 
{ 
    local message="${1:-"Abnormal termination"}";
    local exit_status="${2:-undefined}";
    if ! [[ "${exit_status}" =~ ^[0-9]+$ ]]; then
        exit_status=1;
    fi;
    log::error_trace "${message}" 3 || echo "Sopka: Unable to log error: ${message}" 1>&2;
    if [ "${exit_status}" != 0 ]; then
        return "${exit_status}";
    fi;
    return 1
}
softfail () 
{ 
    softfail::internal "$@"
}
sopka::add_sopkafile () 
{ 
    local user_name;
    user_name="$(<<<"$1" cut -d "/" -f 1)" || softfail || return $?;
    local repo_name;
    repo_name="$(<<<"$1" cut -d "/" -f 2)" || softfail || return $?;
    git::place_up_to_date_clone "https://github.com/${user_name}/${repo_name}.git" "${HOME}/.sopka/sopkafiles/${repo_name}-${user_name}-github" || softfail || return $?
}
sopka::deploy_sh_main () 
{ 
    if [ "${SOPKA_VERBOSE:-}" = true ]; then
        set -o xtrace;
    fi;
    set -o nounset;
    task::run_with_install_filter git::install_git || softfail || return $?;
    task::run_with_install_filter git::place_up_to_date_clone "https://github.com/senotrusov/sopka.git" "${HOME}/.sopka" || softfail || return $?;
    deploy_script "$@";
    softfail_unless_good_code $?
}
task::complete_with_cleanup () 
{ 
    task::complete || softfail || return $?;
    if [ "${SOPKA_TASK_KEEP_TEMP_FILES:-}" != true ]; then
        rm -fd "${temp_dir}/stdout" "${temp_dir}/stderr" "${temp_dir}" || softfail || return $?;
    fi
}
task::complete () 
{ 
    local error_state=0;
    local stderr_present=false;
    if [ "${task_status:-1}" = 0 ] && [ -s "${temp_dir}/stderr" ]; then
        stderr_present=true;
        if [ -n "${SOPKA_TASK_STDERR_FILTER:-}" ] && task::is_stderr_empty_after_filtering "${temp_dir}/stderr"; then
            stderr_present=false;
        fi;
    fi;
    if [ "${task_status:-1}" != 0 ] || [ "${stderr_present}" = true ] || [ "${SOPKA_VERBOSE:-}" = true ] || [ "${SOPKA_TASK_VERBOSE:-}" = true ]; then
        if [ -s "${temp_dir}/stdout" ]; then
            cat "${temp_dir}/stdout" || { 
                echo "Sopka: Unable to display task stdout ($?)" 1>&2;
                error_state=1
            };
        fi;
        if [ -s "${temp_dir}/stderr" ]; then
            test -t 2 && terminal::color 9 1>&2;
            cat "${temp_dir}/stderr" 1>&2 || { 
                echo "Sopka: Unable to display task stderr ($?)" 1>&2;
                error_state=2
            };
            test -t 2 && terminal::default_color 1>&2;
        fi;
    fi;
    if [ "${error_state}" != 0 ]; then
        softfail "task::cleanup error state ${error_state}" || return $?;
    fi
}
task::detect_fail_state () 
{ 
    local task_status="$3";
    if [ -z "${SOPKA_TASK_FAIL_DETECTOR:-}" ]; then
        return "${task_status}";
    fi;
    "${SOPKA_TASK_FAIL_DETECTOR}" "$@"
}
task::install_filter () 
{ 
    grep -vFx "Success." | grep -vFx "Warning: apt-key output should not be parsed (stdout is not a terminal)" | grep -vx "Cloning into '.*'\\.\\.\\.";
    if ! [[ "${PIPESTATUS[*]}" =~ ^([01][[:blank:]])*[01]$ ]]; then
        softfail || return $?;
    fi
}
task::is_stderr_empty_after_filtering () 
{ 
    local stderr_file="$1";
    local stderr_size;
    stderr_size="$("${SOPKA_TASK_STDERR_FILTER}" <"${stderr_file}" | awk NF | wc -c; test "${PIPESTATUS[*]}" = "0 0 0")" || softfail || return $?;
    if [ "${stderr_size}" != 0 ]; then
        return 1;
    fi
}
task::run_with_install_filter () 
{ 
    local SOPKA_TASK_STDERR_FILTER=task::install_filter;
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
    local temp_dir;
    temp_dir="$(mktemp -d)" || fail;
    trap "task::complete_with_cleanup" EXIT;
    if [ -t 0 ]; then
        ( "$@" ) < /dev/null > "${temp_dir}/stdout" 2> "${temp_dir}/stderr";
    else
        ( "$@" ) > "${temp_dir}/stdout" 2> "${temp_dir}/stderr";
    fi;
    local task_status=$?;
    task::detect_fail_state "${temp_dir}/stdout" "${temp_dir}/stderr" "${task_status}";
    local task_status=$?;
    exit "${task_status}" )
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
terminal::default_color () 
{ 
    if command -v tput > /dev/null; then
        tput sgr 0 || echo "Sopka: Unable to get terminal sequence from tput ($?)" 1>&2;
    fi
}

sopka::deploy_sh_main "$@"

}; __xVhMyefCbBnZFUQtwqCs "$@"
