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

fail () 
{ 
    softfail::internal "$@";
    exit $?
}
fail_code () 
{ 
    softfail::internal "" "$1";
    exit $?
}
fail_unless_good () 
{ 
    softfail_unless_good::internal "$@" || exit $?
}
fail_unless_good_code () 
{ 
    softfail_unless_good::internal "" "$1" || exit $?
}
softfail () 
{ 
    softfail::internal "$@"
}
softfail_code () 
{ 
    softfail::internal "" "$1"
}
softfail_unless_good () 
{ 
    softfail_unless_good::internal "$@"
}
softfail_unless_good_code () 
{ 
    softfail_unless_good::internal "" "$1"
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
task::with_verbose_task () 
{ 
    ( if [ -t 1 ]; then
        log::notice "SOPKA_TASK_VERBOSE flag is set" || softfail || return $?;
    fi;
    export SOPKA_TASK_VERBOSE=true;
    "$@" )
}
task::with_update_secrets () 
{ 
    ( if [ -t 1 ]; then
        log::notice "SOPKA_UPDATE_SECRETS flag is set" || softfail || return $?;
    fi;
    export SOPKA_UPDATE_SECRETS=true;
    "$@" )
}
task::ssh_jump () 
{ 
    local SOPKA_TASK_SSH_JUMP=true;
    "$@"
}
task::run_with_install_filter () 
{ 
    local SOPKA_TASK_STDERR_FILTER=task::install_filter;
    task::run "$@"
}
task::run_with_rubygems_fail_detector () 
{ 
    local SOPKA_TASK_FAIL_DETECTOR=task::rubygems_fail_detector;
    task::run "$@"
}
task::run_without_title () 
{ 
    local SOPKA_TASK_OMIT_TITLE=true;
    task::run "$@"
}
task::run_with_title () 
{ 
    local SOPKA_TASK_TITLE="$1";
    task::run "${@:2}"
}
task::run_with_short_title () 
{ 
    local SOPKA_TASK_TITLE="$1";
    task::run "$@"
}
task::run_verbose () 
{ 
    local SOPKA_TASK_VERBOSE=true;
    task::run "$@"
}
task::rubygems_fail_detector () 
{ 
    local stderr_file="$2";
    local task_status="$3";
    if [ "${task_status}" = 0 ] && [ -s "${stderr_file}" ] && grep -q "^ERROR:" "${stderr_file}"; then
        return 1;
    fi;
    return "${task_status}"
}
task::detect_fail_state () 
{ 
    local task_status="$3";
    if [ -z "${SOPKA_TASK_FAIL_DETECTOR:-}" ]; then
        return "${task_status}";
    fi;
    "${SOPKA_TASK_FAIL_DETECTOR}" "$@"
}
task::run () 
{ 
    ( if [ "${SOPKA_TASK_SSH_JUMP:-}" = true ]; then
        ssh::task "$@";
        return $?;
    fi;
    if [ "${SOPKA_TASK_OMIT_TITLE:-}" != true ]; then
        log::notice "Performing '${SOPKA_TASK_TITLE:-"$*"}'..." || softfail || return $?;
    fi;
    local temp_dir;
    temp_dir="$(mktemp -d)" || softfail || return $?;
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
log::elapsed_time () 
{ 
    echo "Elapsed time: $((SECONDS / 3600))h$(((SECONDS % 3600) / 60))m$((SECONDS % 60))s"
}
log::error () 
{ 
    local message="$1";
    log::with_color "${message}" 9 1>&2
}
log::warning () 
{ 
    local message="$1";
    log::with_color "${message}" 11 1>&2
}
log::notice () 
{ 
    local message="$1";
    log::with_color "${message}" 14
}
log::success () 
{ 
    local message="$1";
    log::with_color "${message}" 10
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
terminal::have_16_colors () 
{ 
    local amount;
    command -v tput > /dev/null && amount="$(tput colors 2>/dev/null)" && [[ "${amount}" =~ ^[0-9]+$ ]] && [ "${amount}" -ge 16 ]
}
terminal::print_color_table () 
{ 
    for i in {0..16..1};
    do
        echo "$(tput setaf "${i}")tput setaf ${i}$(tput sgr 0)";
    done;
    for i in {0..16..1};
    do
        echo "$(tput setab "${i}")tput setab ${i}$(tput sgr 0)";
    done
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
deploy_script::add () 
{ 
    task::run_with_install_filter sopkafile::add "$1" || softfail || return $?;
    deploy_script "${@:2}";
    softfail_unless_good_code $?
}
deploy_script::run () 
{ 
    "${HOME}/.sopka/bin/sopka" "$@";
    softfail_unless_good_code $?
}

apt::install () 
{ 
    task::run_with_title "apt-get install $*" sudo DEBIAN_FRONTEND=noninteractive apt-get -y install "$@" || softfail || return $?
}
apt::update () 
{ 
    task::run_with_title "apt-get update" sudo DEBIAN_FRONTEND=noninteractive apt-get update || softfail || return $?
}

git::install_git () 
{ 
    if [[ "${OSTYPE}" =~ ^linux ]]; then
        if ! command -v git > /dev/null; then
            if command -v apt-get > /dev/null; then
                apt::update || softfail || return $?;
                apt::install git || softfail || return $?;
            else
                fail "Unable to install git, apt-get not found";
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
    local url="$1";
    shift;
    local dest="$1";
    shift;
    while [[ "$#" -gt 0 ]]; do
        case $1 in 
            -b | --branch)
                local branch="$2";
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
    if [ -d "${dest}" ]; then
        local current_url;
        current_url="$(git -C "${dest}" config remote.origin.url)" || softfail || return $?;
        if [ "${current_url}" != "${url}" ]; then
            local dest_full_path;
            dest_full_path="$(cd "${dest}" >/dev/null 2>&1 && pwd)" || softfail || return $?;
            local dest_parent_dir;
            dest_parent_dir="$(dirname "${dest_full_path}")" || softfail || return $?;
            local dest_dir_name;
            dest_dir_name="$(basename "${dest_full_path}")" || softfail || return $?;
            local backup_path;
            backup_path="$(mktemp -u "${dest_parent_dir}/${dest_dir_name}-SOPKA-PREVIOUS-CLONE-XXXXXXXXXX")" || softfail || return $?;
            mv "${dest_full_path}" "${backup_path}" || softfail || return $?;
            git clone "${url}" "${dest}" || softfail "Unable to git clone ${url} to ${dest}" || return $?;
        fi;
        if [ -n "${branch:-}" ]; then
            git -C "${dest}" pull origin "${branch}" || softfail "Unable to git pull in ${dest}" || return $?;
        else
            git -C "${dest}" pull || softfail "Unable to git pull in ${dest}" || return $?;
        fi;
    else
        git clone "${url}" "${dest}" || softfail "Unable to git clone ${url} to ${dest}" || return $?;
    fi;
    if [ -n "${branch:-}" ]; then
        git -C "${dest}" checkout "${branch}" || softfail "Unable to git checkout ${branch} in ${dest}" || return $?;
    fi
}

sopkafile::add () 
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

sopka::deploy_sh_main "$@"

}; __xVhMyefCbBnZFUQtwqCs "$@"
