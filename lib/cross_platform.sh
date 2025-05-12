#!/usr/bin/env bash

#  Copyright 2012-2025 Runag project contributors
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

# ## `cross_platform::config_home`
#
# Determines the platform-specific configuration home directory.
#
# This function checks the `OSTYPE` environment variable to identify the
# operating system and then outputs the conventional path for user-specific
# application configuration files. It supports Linux, macOS (darwin), and
# Windows (msys).
#
# ### Usage
#
# cross_platform::config_home
#
cross_platform::config_home() {
  # Determine configuration directory based on the operating system type
  case "${OSTYPE}" in
    linux*)
      # For Linux, use XDG_CONFIG_HOME or default to ~/.config
      echo "${XDG_CONFIG_HOME:-"${HOME}/.config"}"
      ;;
    darwin*)
      # For macOS, use ~/Library/Application Support
      echo "${HOME}/Library/Application Support"
      ;;
    msys*)
      # For Windows (msys/git bash), use APPDATA
      echo "${APPDATA}"
      ;;
    *)
      # If the platform is not recognized, report a soft failure
      softfail "The operating system platform is not supported." || return $?
      ;;
  esac
}
