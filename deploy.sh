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


# This script is wrapped inside a function with a random name to lower the chance for the bash to run some 
# unexpected commands in case if "curl | bash" fails in the middle of download.
__xVhMyefCbBnZFUQtwqCs() {

deploy_script () 
{ 
    if [ -n "${1:-}" ]; then
        if declare -f "deploy_script::$1" > /dev/null; then
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
    task::run --install-filter runagfile::add "$1" || softfail || return $?;
    deploy_script "${@:2}";
    softfail --exit-status $? --unless-good
}
deploy_script::run () 
{ 
    "${HOME}/.runag/bin/runag" "$@";
    softfail --exit-status $? --unless-good
}
fail () 
{ 
    local exit_status="";
    local unless_good=false;
    local perform_softfail=false;
    local trace_start=2;
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
                trace_start=3;
                shift
            ;;
            -*)
                { 
                    declare -f "log::error" > /dev/null && log::error "Unknown argument for fail: $1"
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
        declare -f "log::error" > /dev/null && log::error "${message}"
    } || echo "${message}" 1>&2;
    fail::trace --start "${trace_start}" || echo "Unable to log stack trace" 1>&2;
    if [ "${perform_softfail}" = true ]; then
        return "${exit_status}";
    fi;
    exit "${exit_status}"
}
fail::trace () 
{ 
    local trace_start=1;
    while [[ "$#" -gt 0 ]]; do
        case $1 in 
            -s | --start)
                trace_start="$2";
                shift;
                shift
            ;;
            *)
                { 
                    declare -f "log::error" > /dev/null && log::error "Unknown argument for fail::trace: $1"
                } || echo "Unknown argument for fail::trace: $1" 1>&2;
                break
            ;;
        esac;
    done;
    local line i trace_end=$((${#BASH_LINENO[@]}-1));
    for ((i=trace_start; i<=trace_end; i++))
    do
        line="  ${BASH_SOURCE[${i}]}:${BASH_LINENO[$((i-1))]}: in \`${FUNCNAME[${i}]}'";
        { 
            declare -f "log::error" > /dev/null && log::error "${line}"
        } || echo "${line}" 1>&2;
    done
}
softfail () 
{ 
    fail --wrapped-softfail "$@"
}
log::error () 
{ 
    local message="$1";
    log::message --foreground-color 9 "${message}" 1>&2
}
log::warning () 
{ 
    local message="$1";
    log::message --foreground-color 11 "${message}" 1>&2
}
log::notice () 
{ 
    local message="$1";
    log::message --foreground-color 14 "${message}"
}
log::success () 
{ 
    local message="$1";
    log::message --foreground-color 10 "${message}"
}
log::message () 
{ 
    local foreground_color_seq="";
    local background_color_seq="";
    local message="";
    while [[ "$#" -gt 0 ]]; do
        case $1 in 
            -f | --foreground-color)
                if [ -t 1 ]; then
                    foreground_color_seq="$(terminal::color --foreground "$2")" || echo "Unable to obtain terminal::color ($?)" 1>&2;
                fi;
                shift;
                shift
            ;;
            -b | --background-color)
                if [ -t 1 ]; then
                    background_color_seq="$(terminal::color --background "$2")" || echo "Unable to obtain terminal::color ($?)" 1>&2;
                fi;
                shift;
                shift
            ;;
            -*)
                echo "Unknown argument for log::message: $1" 1>&2;
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
        message="(empty log message)";
    fi;
    local default_color_seq="";
    if [ -t 1 ]; then
        default_color_seq="$(terminal::default_color)" || echo "Unable to obtain terminal::color ($?)" 1>&2;
    fi;
    echo "${foreground_color_seq}${background_color_seq}${message}${default_color_seq}"
}
log::elapsed_time () 
{ 
    log::notice "Elapsed time: $((SECONDS / 3600))h$(((SECONDS % 3600) / 60))m$((SECONDS % 60))s"
}
task::run () 
{ 
    ( local short_title=false;
    local task_title="";
    while [[ "$#" -gt 0 ]]; do
        case $1 in 
            -e | --stderr-filter)
                local RUNAG_TASK_STDERR_FILTER="$2";
                shift;
                shift
            ;;
            -i | --install-filter)
                local RUNAG_TASK_STDERR_FILTER=task::install_filter;
                shift
            ;;
            -f | --fail-detector)
                local RUNAG_TASK_FAIL_DETECTOR="$2";
                shift;
                shift
            ;;
            -r | --rubygems-fail-detector)
                local RUNAG_TASK_FAIL_DETECTOR=task::rubygems_fail_detector;
                shift
            ;;
            -t | --title)
                task_title="$2";
                shift;
                shift
            ;;
            -s | --short-title)
                short_title=true;
                shift
            ;;
            -o | --omit-title)
                local RUNAG_TASK_OMIT_TITLE=true;
                shift
            ;;
            -k | --keep-temp-files)
                local RUNAG_TASK_KEEP_TEMP_FILES=true;
                shift
            ;;
            -v | --verbose)
                local RUNAG_TASK_VERBOSE=true;
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
    if [ "${short_title}" = true ]; then
        task_title="$1";
    fi;
    if [ "${RUNAG_TASK_OMIT_TITLE:-}" != true ]; then
        log::notice "Performing '${task_title:-"$*"}'..." || softfail || return $?;
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
    stderr_size="$("${RUNAG_TASK_STDERR_FILTER}" <"${stderr_file}" | awk NF | wc -c; test "${PIPESTATUS[*]}" = "0 0 0")" || fail;
    if [ "${stderr_size}" != 0 ]; then
        return 1;
    fi
}
task::detect_fail_state () 
{ 
    local task_status="$3";
    if [ -z "${RUNAG_TASK_FAIL_DETECTOR:-}" ]; then
        return "${task_status}";
    fi;
    "${RUNAG_TASK_FAIL_DETECTOR}" "$@"
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
task::complete () 
{ 
    local error_state=0;
    local stderr_present=false;
    if [ "${task_status:-1}" = 0 ] && [ -s "${temp_dir}/stderr" ]; then
        stderr_present=true;
        if [ -n "${RUNAG_TASK_STDERR_FILTER:-}" ] && task::is_stderr_empty_after_filtering "${temp_dir}/stderr"; then
            stderr_present=false;
        fi;
    fi;
    if [ "${task_status:-1}" != 0 ] || [ "${stderr_present}" = true ] || [ "${RUNAG_VERBOSE:-}" = true ] || [ "${RUNAG_TASK_VERBOSE:-}" = true ]; then
        if [ -s "${temp_dir}/stdout" ]; then
            cat "${temp_dir}/stdout" || { 
                echo "Unable to display task stdout ($?)" 1>&2;
                error_state=1
            };
        fi;
        if [ -s "${temp_dir}/stderr" ]; then
            test -t 2 && terminal::color --foreground 9 1>&2;
            cat "${temp_dir}/stderr" 1>&2 || { 
                echo "Unable to display task stderr ($?)" 1>&2;
                error_state=2
            };
            test -t 2 && terminal::default_color 1>&2;
        fi;
    fi;
    if [ "${error_state}" != 0 ]; then
        softfail "task::cleanup error state ${error_state}" || return $?;
    fi
}
task::complete_with_cleanup () 
{ 
    task::complete || softfail || return $?;
    if [ "${RUNAG_TASK_KEEP_TEMP_FILES:-}" != true ]; then
        rm -fd "${temp_dir}/stdout" "${temp_dir}/stderr" "${temp_dir}" || softfail || return $?;
    fi
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
    local foreground_color="";
    local background_color="";
    while [[ "$#" -gt 0 ]]; do
        case $1 in 
            -f | --foreground)
                foreground_color="$2";
                shift;
                shift
            ;;
            -b | --background)
                background_color="$2";
                shift;
                shift
            ;;
            -*)
                echo "Unknown argumen for terminal::color: $1" 1>&2;
                return 1
            ;;
            *)
                break
            ;;
        esac;
    done;
    local amount;
    if command -v tput > /dev/null && amount="$(tput colors 2>/dev/null)" && [[ "${amount}" =~ ^[0-9]+$ ]]; then
        if [[ "${foreground_color:-}" =~ ^[0-9]+$ ]] && [ "${amount}" -ge "${foreground_color:-}" ]; then
            tput setaf "${foreground_color}" || { 
                echo "Unable to get terminal sequence from tput in terminal::color ($?)" 1>&2;
                return 1
            };
        fi;
        if [[ "${background_color:-}" =~ ^[0-9]+$ ]] && [ "${amount}" -ge "${background_color:-}" ]; then
            tput setab "${background_color}" || { 
                echo "Unable to get terminal sequence from tput in terminal::color ($?)" 1>&2;
                return 1
            };
        fi;
    fi
}
terminal::default_color () 
{ 
    if command -v tput > /dev/null; then
        tput sgr 0 || { 
            echo "Unable to get terminal sequence from tput in terminal::color ($?)" 1>&2;
            return 1
        };
    fi
}

apt::install () 
{ 
    task::run --title "apt-get install $*" sudo DEBIAN_FRONTEND=noninteractive apt-get -y install "$@" || softfail || return $?
}
apt::update () 
{ 
    task::run --title "apt-get update" sudo DEBIAN_FRONTEND=noninteractive apt-get update || softfail || return $?
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
    task::run --install-filter git::install_git || softfail || return $?;
    task::run --install-filter git::place_up_to_date_clone "${RUNAG_DIST_REPO}" "${HOME}/.runag" || softfail || return $?;
    deploy_script "$@";
    softfail --exit-status $? --unless-good
}

export RUNAG_DIST_REPO="${RUNAG_DIST_REPO:-https://github.com/runag/runag.git}"

runag::deploy_sh_main "$@"

}; __xVhMyefCbBnZFUQtwqCs "$@"
