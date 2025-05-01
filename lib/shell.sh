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
  softfail --unless-good --status $? || return $?

  "$@"
)

# ## `shell::emit_exports`
#
# Outputs shell `export` statements for each non-empty variable passed as argument.
# Intended for persisting or scripting variable values in a safe, quoted format.
#
# ### Usage
#
# shell::emit_exports VAR1 VAR2 ...
#
# * `VAR1`, `VAR2`, ...: names of variables whose values should be exported
#
# ### Examples
#
# shell::emit_exports PATH HOME CUSTOM_VAR
#
shell::emit_exports() {
  local list_item; for list_item in "$@"; do
    if [[ -n "${!list_item:-}" ]]; then
      # Output a properly quoted export statement for non-empty variables
      echo "export $(printf "%q=%q" "${list_item}" "${!list_item}")"
    fi
  done
}

# shellcheck disable=SC2016
shell::enable_trace() {
  PS4='+${BASH_SUBSHELL} ${BASH_SOURCE:+"${BASH_SOURCE}:${LINENO}: "}${FUNCNAME[0]:+"in \`${FUNCNAME[0]}'"'"' "}** '
  set -o xtrace
}

shell::assign_and_mark_for_export() {
  # `declare -g` requires Bash 4.2 or newer (released in 2011)
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

shell::open() {
  "${SHELL}" "$@" || true
}
