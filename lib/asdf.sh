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

# ### `asdf::extend_package_list::debian`
#
# #### Usage
#
# asdf::extend_package_list::debian
#
asdf::extend_package_list::debian() {
  package_list+=(
    curl  # Command-line tool for transferring data using various protocols.
    git   # Version control system for tracking changes in source code.
  )
}

# ### `asdf::extend_package_list::arch`
#
# #### Usage
#
# asdf::extend_package_list::arch
#
asdf::extend_package_list::arch() {
  package_list+=(
    curl  # Command-line tool for transferring data using various protocols.
    git   # Version control system for tracking changes in source code.
  )
}

asdf::install_self() {
  local version_tag
  
  version_tag="${1:-"$(github::query_release --get tag_name asdf-vm/asdf)"}" \
    || softfail "Unable to obtain asdf version tag" || return $?

  git::place_up_to_date_clone \
    --branch "${version_tag}" \
    "https://github.com/asdf-vm/asdf.git" \
    "${HOME}/.asdf" \
      || softfail || return $?
}

asdf::install_shellfile() {
  local license_text; license_text="$(runag::print_license)" || softfail || return $?

  shellfile::write "profile/asdf" <<SHELL || softfail || return $?
${license_text}

if [ -f "\${HOME}/.asdf/asdf.sh" ]; then
  . "\${HOME}/.asdf/asdf.sh" || { echo "Unable to load asdf" >&2; return 1; }
fi
SHELL

  shellfile::write "rc/asdf" <<SHELL || softfail || return $?
${license_text}

if [ -f "\${HOME}/.asdf/asdf.sh" ]; then
  . "\${HOME}/.asdf/asdf.sh" || { echo "Unable to load asdf" >&2; return 1; }

  if [ -n "\${BASH_VERSION:-}" ]; then
    . "\${HOME}/.asdf/completions/asdf.bash" || { echo "Unable to load asdf completions" >&2; return 1; }

  elif [ -n "\${ZSH_VERSION:-}" ]; then
    fpath=(\${ASDF_DIR}/completions \${fpath}) || { echo "Unable to set fpath" >&2; return 1; }
    autoload -Uz compinit || { echo "Unable to set compinit function to autoload" >&2; return 1; }
    compinit || { echo "Unable to run compinit" >&2; return 1; }

  fi
fi
SHELL
}

asdf::load() {
  . "${HOME}/.asdf/asdf.sh" || softfail "Unable to load asdf" || return $?
}

asdf::install() {
  local set_global=false

  while [ "$#" -gt 0 ]; do
    case "$1" in
      -g|--global)
        set_global=true
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

  local plugin_name="$1"
  local package_version="${2:-"latest"}"

  asdf plugin add "${plugin_name}" || softfail || return $?
  asdf plugin update "${plugin_name}" || softfail || return $?

  # TODO: check if `plugin update` needed right after `plugin add`

  asdf install "${plugin_name}" "${package_version}" || softfail || return $?

  if [ "${set_global}" = true ]; then
    asdf global "${plugin_name}" "${package_version}" || softfail || return $?
  fi
}
