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

shell::install_rc_loader() { (
  if [[ "${OSTYPE}" =~ ^darwin ]]; then
    local shellrc_file=".zshrc"
  else
    local shellrc_file=".bashrc"
  fi

  local shellrc_dir=".shellrc.d"
  local block_name="rc-d-loader"

  while [[ "$#" -gt 0 ]]; do
    case $1 in
    -f|--file)
      shellrc_file="$2"
      shift; shift
      ;;
    -d|--dir)
      shellrc_dir="$2"
      shift; shift
      ;;
    -b|--block-name)
      block_name="$2"
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

  cd "${HOME}" || softfail || return $?

  dir::should_exists --mode 0700 "${shellrc_dir}" || softfail || return $?

  # I use a random variable name here to reduce the chance of overwriting someone else's data
  file::write_block --keep-permissions --mode 0644 "${shellrc_file}" "${block_name}" <<SHELL || softfail || return $?
if [ -d "\${HOME}"/$(printf "%q" "${shellrc_dir}") ]; then
  for __file_bb21go6nkCN82Gk9XeY2 in "\${HOME}"/$(printf "%q" "${shellrc_dir}")/*.sh; do
    if [ -f "\${__file_bb21go6nkCN82Gk9XeY2}" ]; then
      . "\${__file_bb21go6nkCN82Gk9XeY2}" || { echo "Unable to load file \${__file_bb21go6nkCN82Gk9XeY2} (\$?)" >&2; }
    fi
  done
  unset __file_bb21go6nkCN82Gk9XeY2
fi
SHELL
) }

shellrc::get_filename() {
  local name="$1"

  local shellrc_dir="${HOME}/.shellrc.d"

  dir::should_exists --mode 0700 "${shellrc_dir}" || softfail || return $?
  echo "${shellrc_dir}/${name}.sh" || softfail || return $?
}

shellrc::write() {
  local name="$1"

  local shellrc_dir="${HOME}/.shellrc.d"

  dir::should_exists --mode 0700 "${shellrc_dir}" || softfail || return $?
  # TODO: --absorb?
  file::write --mode 0600 "${shellrc_dir}/${name}.sh" || softfail || return $?
}

shellrc::load() {
  local name="$1"

  local shellrc_dir="${HOME}/.shellrc.d"

  . "${shellrc_dir}/${name}.sh" || softfail || return $?
}

shellrc::load_if_exists() {
  local name="$1"

  local shellrc_dir="${HOME}/.shellrc.d"

  if [ -f "${shellrc_dir}/${name}.sh" ]; then
    . "${shellrc_dir}/${name}.sh" || softfail || return $?
  fi
}

shell::set_runag_rc() {
  file::write --mode 0640 "${HOME}/.profile.d/runag.sh" <<SHELL || softfail || return $?
$(runag::print_license)

if [ -d "\${HOME}/.runag/bin" ]; then
  case ":\${PATH}:" in
  *":\${HOME}/.runag/bin:"*)
    true
    ;;
  *)
    export PATH="\${HOME}/.runag/bin:\${PATH}"
    ;;
  esac
fi
SHELL
}

shell::set_direnv_rc() {
  file::write --mode 0640 "${HOME}/.shellrc.d/direnv.sh" <<SHELL || softfail || return $?
$(runag::print_license)

if command -v direnv >/dev/null; then
  export DIRENV_LOG_FORMAT=""
  if [ -n "\${ZSH_VERSION:-}" ]; then
    eval "\$(direnv hook zsh)" || echo "Unable to hook direnv" >&2
  elif [ -n "\${BASH_VERSION:-}" ]; then
    eval "\$(direnv hook bash)" || echo "Unable to hook direnv" >&2
  fi
fi
SHELL
}

shell::set_editor_rc() {
  local editor_path; editor_path="$(command -v "$1")" || softfail || return $?

  file::write --mode 0640 "${HOME}/.shellrc.d/editor.sh" <<SHELL || softfail || return $?
$(runag::print_license)

if [ -z "\${EDITOR:-}" ]; then
  export EDITOR=$(printf "%q" "${editor_path}")
fi
SHELL
}

shell::set_flush_history_rc() {
  file::write --mode 0640 "${HOME}/.shellrc.d/flush-history.sh" <<SHELL || softfail || return $?
$(runag::print_license)

if [ -n "\${BASH_VERSION:-}" ]; then
  export PROMPT_COMMAND="\${PROMPT_COMMAND:+"\${PROMPT_COMMAND}; "}history -a"
fi
SHELL
}
