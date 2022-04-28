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

sopka::with_update_secrets() {(
  if [ -t 1 ]; then
    log::notice "SOPKA_UPDATE_SECRETS flag is set" || fail
  fi
  export SOPKA_UPDATE_SECRETS=true
  "$@"
)}

sopka::with_verbose_tasks() {(
  if [ -t 1 ]; then
    log::notice "SOPKA_TASK_VERBOSE flag is set" || fail
  fi
  export SOPKA_TASK_VERBOSE=true
  "$@"
)}

sopka::linux::run_benchmark() {
  benchmark::run || softfail || return $?
}

sopka::linux::display_if_restart_required() {
  linux::display_if_restart_required || softfail || return $?
}

sopka::linux::dangerously_set_hostname() {
  echo "Please keep in mind that the script to change hostname is not perfect, please take time to review the script and it's results"
  echo "Please enter new hostname:"
  
  local hostname; IFS="" read -r hostname || softfail || return $?

  linux::dangerously_set_hostname "${hostname}" || softfail || return $?
}

sopka::install_as_repository_clone() {
  git::place_up_to_date_clone "https://github.com/senotrusov/sopka.git" "${HOME}/.sopka" || softfail || return $?
}

sopka::update() {
  if [ -d "${HOME}/.sopka/.git" ]; then
    git -C "${HOME}/.sopka" pull || softfail || return $?

    local sopkafile_dir; for sopkafile_dir in "${HOME}"/.sopka/sopkafiles/*; do
      if [ -d "${sopkafile_dir}/.git" ]; then
        git -C "${sopkafile_dir}" pull || softfail || return $?
      fi
    done
  fi
}

sopka::print_license() {
  cat <<SHELL
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
SHELL
}

sopka::add_sopkafile() {
  local user_name; user_name="$(<<<"$1" cut -d "/" -f 1)" || softfail || return $?
  local repo_name; repo_name="$(<<<"$1" cut -d "/" -f 2)" || softfail || return $?
  git::place_up_to_date_clone "https://github.com/${user_name}/${repo_name}.git" "${HOME}/.sopka/sopkafiles/${repo_name}-${user_name}-github" || softfail || return $?
}

# Find and load sopkafile.
#
# Possible locations are:
#
# ./sopkafile
# ./sopkafile/index.sh
#
# ~/.sopkafile
# ~/.sopkafile/index.sh
#
# ~/.sopka/sopkafiles/*/index.sh
#
sopka::load_sopkafile() {
  if [ -f "./sopkafile.sh" ]; then
    . "./sopkafile.sh"
    softfail_unless_good "Unable to load './sopkafile.sh' ($?)" $?
    return $?

  elif [ -f "./sopkafile/index.sh" ]; then
    . "./sopkafile/index.sh"
    softfail_unless_good "Unable to load './sopkafile/index.sh' ($?)" $?
    return $?

  elif [ -n "${HOME:-}" ] && [ -f "${HOME:-}/.sopkafile.sh" ]; then
    . "${HOME:-}/.sopkafile.sh"
    softfail_unless_good "Unable to load '${HOME:-}/.sopkafile.sh' ($?)" $?
    return $?

  elif [ -n "${HOME:-}" ] && [ -f "${HOME:-}/.sopkafile/index.sh" ]; then
    . "${HOME:-}/.sopkafile/index.sh"
    softfail_unless_good "Unable to load '${HOME:-}/.sopkafile/index.sh' ($?)" $?
    return $?

  else
    sopka::load_all_sopkafiles_from_sopka
    softfail_unless_good "Unable to load sopkafiles from .sopka ($?)" $? || return $?
  fi
}

sopka::load_all_sopkafiles_from_sopka() {
  local file_path; for file_path in "${HOME}"/.sopka/sopkafiles/*/index.sh; do
    if [ -f "${file_path}" ]; then
      . "${file_path}"
      softfail_unless_good "Unable to load '${file_path}' ($?)" $? || return $?
    fi
  done
}

sopka::should_deploy() {
  local item="$1"
  [[ " ${SOPKA_DEPLOY_LIST} " == *" ${item} "* ]]
}

sopka::should_deploy_auth() {
  local item="$1"
  [[ " ${SOPKA_AUTH_DEPLOY_LIST} " == *" ${item} "* ]]
}
