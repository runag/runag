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

# ## `platform::config_home`
#
# Determines the platform-specific configuration home directory.
#
# This function checks the `OSTYPE` environment variable to identify the
# operating system and then outputs the conventional path for user-specific
# application configuration files. It supports Linux, macOS, and
# Windows.
#
# ### Usage
#
# platform::config_home
#
platform::config_home() {
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
    msys*|cygwin*)
      # For Windows, use APPDATA
      echo "${APPDATA}"
      ;;
    *)
      # If the platform is not recognized, report a soft failure
      softfail "The operating system platform is not supported."
      return 1
      ;;
  esac
}

# ## `platform::copy_to_clipboard`
#
# Copies standard input to the system clipboard.
#
# This function attempts to use various clipboard tools (wl-copy, xclip,
# pbcopy) in a preferred order. If none of these tools are available,
# it prints the input to standard output as a fallback.
#
# ### Usage
#
# platform::copy_to_clipboard
#
platform::copy_to_clipboard() {
  # Attempt to use wl-copy (Wayland-based Linux) if available
  if command -v wl-copy >/dev/null 2>&1; then
    wl-copy || softfail "Could not access the clipboard using wl-copy." || return 1

  # Else, attempt to use xclip (X11-based Linux) if available
  elif command -v xclip >/dev/null 2>&1; then
    xclip -selection clipboard || softfail "Could not access the clipboard using xclip." || return 1

  # Else, attempt to use pbcopy (macOS) if available
  elif command -v pbcopy >/dev/null 2>&1; then
    pbcopy || softfail "Could not access the clipboard using pbcopy." || return 1
  
  # Attempt to use clip (Windows) if available
  elif command -v clip >/dev/null 2>&1; then
    clip || softfail "Could not access the clipboard using clip." || return 1

  # If no clipboard tool is found, print to standard output
  else
    echo "No clipboard tool was found. Printing to standard output instead:" >&2
    cat || softfail "Failed to read from stdin." || return 1
    
    # This is not necessarily an error since the data was displayed
    return
  fi

  # Notify the user of the successful operation
  echo "Copied to clipboard." >&2
}
