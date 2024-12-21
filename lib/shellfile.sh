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

# TODO: refactor shellfile, bring better ideas

shellfile::write_loader_block() {
  local file_path
  local directory_path
  local block_name="shellfile-d-loader"

  while [ "$#" -gt 0 ]; do
    case "$1" in
      -f|--file)
        file_path="$2"
        shift; shift
        ;;
      -d|--dir)
        directory_path="$2"
        shift; shift
        ;;
      -b|--block)
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

  # I use a random variable name here to reduce the chance of overwriting someone else's data
  file::write_block --keep-permissions --mode 0644 "${file_path}" "${block_name}" <<SHELL || softfail || return $?
if [ -d "\${HOME}"/$(printf "%q" "${directory_path}") ]; then
  for __file_bb21go6nkCN82Gk9XeY2 in "\${HOME}"/$(printf "%q" "${directory_path}")/*.sh; do
    if [ -f "\${__file_bb21go6nkCN82Gk9XeY2}" ]; then
      . "\${__file_bb21go6nkCN82Gk9XeY2}" || { echo "Unable to load file \${__file_bb21go6nkCN82Gk9XeY2} (\$?)" >&2; }
    fi
  done
  unset __file_bb21go6nkCN82Gk9XeY2
fi
SHELL
}

shellfile::install_loader::bash() {
  shellfile::write_loader_block --file "${HOME}/.bashrc" --dir ".shellfile.d/rc" || softfail || return $?

  # Arch use .bash_profile, Debian use .profile
  if [ -f "${HOME}/.bash_profile" ] || [ ! -f "${HOME}/.profile" ]; then
    shellfile::write_loader_block --file "${HOME}/.bash_profile" --dir ".shellfile.d/profile" || softfail || return $?
  else
    shellfile::write_loader_block --file "${HOME}/.profile" --dir ".shellfile.d/profile" || softfail || return $?
  fi
}

shellfile::install_loader::zsh() {
  shellfile::write_loader_block --file "${HOME}/.zshrc" --dir ".shellfile.d/rc" || softfail || return $?
  shellfile::write_loader_block --file "${HOME}/.zprofile" --dir ".shellfile.d/profile" || softfail || return $?
}

shellfile::write() {
  local source_now=false

  while [ "$#" -gt 0 ]; do
    case "$1" in
      -s|--source-now)
        source_now=true
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

  local file_path="$1"

  # TODO: handle --absorb as an argument and propogate it down to file::write

  local shellfile_dir_path="${HOME}/.shellfile.d"

  dir::ensure_exists --mode 0700 "${shellfile_dir_path}" || softfail || return $?
  dir::ensure_exists --mode 0700 "${shellfile_dir_path}/rc" || softfail || return $?
  dir::ensure_exists --mode 0700 "${shellfile_dir_path}/profile" || softfail || return $?

  local output_path="${shellfile_dir_path}/${file_path}.sh"
  
  file::write --mode 0600 "${output_path}" || softfail || return $?

  if [ "${source_now}" = true ]; then
    . "${output_path}" || softfail || return $?
  fi
}


# ---- misc files

shellfile::install_runag_path_profile() {
  local license_text; license_text="$(runag::print_license)" || softfail || return $?

  shellfile::write "$@" "profile/runag-path" <<SHELL || softfail || return $?
${license_text}

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

shellfile::install_local_bin_path_profile() {
  local license_text; license_text="$(runag::print_license)" || softfail || return $?

  shellfile::write "$@" "profile/local-bin-path" <<SHELL || softfail || return $?
${license_text}

if [ -d "\${HOME}/.local/bin" ]; then
  case ":\${PATH}:" in
  *":\${HOME}/.local/bin:"*)
    true
    ;;
  *)
    export PATH="\${HOME}/.local/bin:\${PATH}"
    ;;
  esac
fi
SHELL
}

shellfile::install_direnv_rc() {
  local license_text; license_text="$(runag::print_license)" || softfail || return $?

  shellfile::write "$@" "rc/direnv" <<SHELL || softfail || return $?
${license_text}

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

# TODO: remove FZF_DEFAULT_OPTS from here

shellfile::install_fzf_rc() {
  local license_text; license_text="$(runag::print_license)" || softfail || return $?

  shellfile::write "$@" "rc/fzf" <<SHELL || softfail || return $?
${license_text}

export FZF_DEFAULT_OPTS="--exact"

if command -v fzf >/dev/null; then
  if [ -n "\${ZSH_VERSION:-}" ]; then
    source <(fzf --zsh) || echo "Unable to hook fzf" >&2
  elif [ -n "\${BASH_VERSION:-}" ]; then
    eval "\$(fzf --bash)" || echo "Unable to hook fzf" >&2
  fi
fi

alias p="pass ff"
SHELL
}

shellfile::install_editor_rc() {
  local editor_path; editor_path="$(command -v "$1")" || softfail || return $?

  shift # TODO: arg parsing and passthrough

  local license_text; license_text="$(runag::print_license)" || softfail || return $?

  shellfile::write "$@" "rc/editor" <<SHELL || softfail || return $?
${license_text}

if [ -z "\${EDITOR:-}" ]; then
  export EDITOR=$(printf "%q" "${editor_path}")
fi
SHELL
}

shellfile::install_flush_history_rc() {
  local license_text; license_text="$(runag::print_license)" || softfail || return $?

  shellfile::write "$@" "rc/flush-history" <<SHELL || softfail || return $?
${license_text}

if [ -n "\${BASH_VERSION:-}" ]; then
  export PROMPT_COMMAND="\${PROMPT_COMMAND:+"\${PROMPT_COMMAND}; "}history -a"
fi
SHELL
}

shellfile::install_short_prompt_rc() {
  local license_text; license_text="$(runag::print_license)" || softfail || return $?

  shellfile::write "$@" "rc/short-prompt" <<SHELL || softfail || return $?
${license_text}

if [ -n "\${BASH_VERSION:-}" ]; then
  if tput cols >/dev/null 2>&1 && [ "\$(tput cols)" -le 140 ]; then
    PS1='\['"\$(tput setaf 12)\$(tput bold)"'\]\W\['"\$(tput sgr 0)"'\]\$ '
  fi
fi
SHELL
}
