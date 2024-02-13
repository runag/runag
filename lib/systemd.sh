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

systemd::write_user_unit() {
  local name="$1"

  local user_units_dir="${HOME}/.config/systemd/user"

  dir::should_exists --mode 0700 "${HOME}/.config" || softfail || return $?
  dir::should_exists --mode 0700 "${HOME}/.config/systemd" || softfail || return $?
  dir::should_exists --mode 0700 "${user_units_dir}" || softfail || return $?

  # TODO: --absorb?
  file::write --mode 0600 "${user_units_dir}/${name}" || softfail || return $?
}

systemd::write_system_unit() {
  local name="$1"

  # TODO: --absorb?
  file::write --sudo --mode 0644 "/etc/systemd/system/${name}" || softfail || return $?
}
