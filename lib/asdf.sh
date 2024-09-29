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

asdf::install_dependencies() (
  . /etc/os-release || softfail || return $?

  if [ "${ID:-}" = debian ] || [ "${ID_LIKE:-}" = debian ]; then
    apt::install \
      curl \
      git \
        || softfail || return $?

  elif [ "${ID:-}" = arch ]; then
    pacman --sync --needed --noconfirm \
      curl \
      git \
        || softfail || return $?
  fi
)

asdf::install() {
  local asdf_version; asdf_version="${1:-"$(github::query_release --get tag_name asdf-vm/asdf)"}" || softfail || return $?
  git::place_up_to_date_clone --branch "${asdf_version}" "https://github.com/asdf-vm/asdf.git" "${HOME}/.asdf" || softfail || return $?
  asdf::load || softfail || return $?
}

asdf::install_with_shellrc() {
  asdf::install || softfail || return $?
  asdf::install_shellfile || softfail || return $?
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
  while [ "$#" -gt 0 ]; do
    case "$1" in
      -i|--if-installed)
        if [ ! -f "${HOME}/.asdf/asdf.sh" ]; then
          return 0
        fi
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

  . "${HOME}/.asdf/asdf.sh" || softfail "Unable to load asdf" || return $?
}

asdf::shim_dir() {
  local home_dir="${HOME}"

  while [ "$#" -gt 0 ]; do
    case "$1" in
      -u|--user)
        home_dir="$(linux::get_home_dir "$2")" || softfail || return $?
        shift; shift
        ;;
      -*)
        softfail "Unknown argument: $1" || return $?
        ;;
      *)
        break
        ;;
    esac
  done

  echo "${ASDF_DATA_DIR:-"${home_dir}/.asdf"}/shims"
}

asdf::path_env() {
  local home_dir="${HOME}"

  while [ "$#" -gt 0 ]; do
    case "$1" in
      -u|--user)
        home_dir="$(linux::get_home_dir "$2")" || softfail || return $?
        shift; shift
        ;;
      -*)
        softfail "Unknown argument: $1" || return $?
        ;;
      *)
        break
        ;;
    esac
  done

  echo "${ASDF_DATA_DIR:-"${home_dir}/.asdf"}/shims:${ASDF_DIR:-"${home_dir}/.asdf"}/bin"
}

asdf::add_plugin() {
  local plugin_name="$1"
  if asdf plugin list | grep -qFx "${plugin_name}"; then
    asdf plugin update "${plugin_name}" || softfail || return $?
  else
    asdf plugin add "$@" || softfail || return $?
  fi
}

asdf::add_plugin_and_install_package() {
  local package_name="$1"
  local package_version="${2:-"latest"}"

  asdf::add_plugin "${package_name}" || softfail || return $?

  asdf install "${package_name}" "${package_version}" || softfail || return $?
}

asdf::add_plugin_install_package_and_set_global() {
  local package_name="$1"
  local package_version="${2:-"latest"}"

  asdf::add_plugin_and_install_package "${package_name}" "${package_version}" || softfail || return $?
  
  asdf global "${package_name}" "${package_version}" || softfail || return $?
}
