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

shell::with() (
  local call_array=()

  while [ "$#" -gt 0 ]; do
    case "$1" in
      --)
        shift
        break
        ;;
      *)
        call_array+=("$1")
        shift
        ;;
    esac
  done

  "${call_array[@]}"
  softfail --unless-good --exit-status $? || return $?

  "$@"
)

shell::dump_variables() {
  local prefix

  while [ "$#" -gt 0 ]; do
    case "$1" in
      -e|--export)
        prefix="export "
        shift
        ;;
      -*)
        softfail "Unknown argument: $1" || return $?
        ;;
      *)
        break
        ;;
    esac
  done

  local list_item; for list_item in "$@"; do
    if [ -n "${!list_item:-}" ]; then
      echo "${prefix:-}$(printf "%q=%q" "${list_item}" "${!list_item}")"
    fi
  done
}

# shellcheck disable=SC2016
shell::enable_trace() {
  PS4='+${BASH_SUBSHELL} ${BASH_SOURCE:+"${BASH_SOURCE}:${LINENO}: "}${FUNCNAME[0]:+"in \`${FUNCNAME[0]}'"'"' "}** '
  set -o xtrace
}

shell::assign_and_mark_for_export() {
  # -g global variable scope
  # -x export
  declare -gx "$1"="$2"
}

shell::unset_locales() {
  # man 5 locale
  # https://wiki.debian.org/Locale
  unset -v \
    LANG \
    LANGUAGE \
    LC_ALL \
    \
    LC_COLLATE \
    LC_CTYPE \
    LC_MESSAGES \
    LC_MONETARY \
    LC_NUMERIC \
    LC_TIME \
    \
    LC_ADDRESS \
    LC_IDENTIFICATION \
    LC_MEASUREMENT \
    LC_NAME \
    LC_PAPER \
    LC_RESPONSE \
    LC_TELEPHONE
}

shell::related_cd() {
  local caller_dir; caller_dir="$(dirname "${BASH_SOURCE[1]}")" || softfail || return $?

  cd "${caller_dir}" || softfail || return $?

  if [ -n "${1:-}" ]; then
    cd "$1" || softfail || return $?
  fi
}

# shell::related_source path [args...]
# shell::related_source --recursive path [args...]

shell::related_source() {
  local caller_dir; caller_dir="$(dirname "${BASH_SOURCE[1]}")" || softfail || return $?

  recursive_flag=false

  while [ "$#" -gt 0 ]; do
    case "$1" in
      -r|--recursive)
        recursive_flag=true
        shift
        ;;
      -*)
        softfail "Unknown argument: $1" || return $?
        ;;
      *)
        break
        ;;
    esac
  done

  if [ "${recursive_flag}" = true ]; then
    shell::related_source::walk_directory "${caller_dir}/$1" "${@:2}" || softfail "Unable to load: ${caller_dir}/$1" || return $?
  else
    . "${caller_dir}/$1" "${@:2}" || softfail "Unable to load: ${caller_dir}/$1" || return $?
  fi
}

shell::related_source::walk_directory() {
  local dir_list=()
  local item dir_item

  for item in "$1/"*; do
    if [ -d "${item}" ]; then
      dir_list+=("${item}")
    elif [ -f "${item}" ] && [[ "${item}" =~ \.sh$ ]]; then
      . "${item}" "${@:2}" || softfail "Unable to load: ${item}" || return $?
    fi
  done

  for dir_item in "${dir_list[@]}"; do
    shell::related_source::walk_directory "${dir_item}" "${@:2}" || softfail "Unable to load: ${dir_item}" || return $?
  done
}
