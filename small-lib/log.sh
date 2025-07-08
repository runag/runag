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

# A simple logging function.
#
# Usage: log [LEVEL] [MESSAGE]
#
# Levels:
#   - error (or err)
#   - warn (or warning)
#   - notice
#   - info (default)
#
# Examples:
#   log error "This is an error message."
#   log warn "This is a warning."
#   log "This is an info message (default level)."
log() {
  # Set defaults: level is INFO, color is magenta.
  local level=""
  local color_code="13"

  # Check if the first argument is a level specifier.
  # Using ${1,,} for case-insensitive matching (e.g., "ERROR" works too).
  case "${1,,}" in
    error|err)    level="Error: ";   color_code="9";  shift ;; # Red
    warn|warning) level="Warning: "; color_code="11"; shift ;; # Yellow
    notice)       level="Notice: ";  color_code="14"; shift ;; # Cyan
    info)         level="";          color_code="13"; shift ;; # Magenta
  esac

  # Get the message from remaining arguments, with a default if none are provided.
  local message="${*:-"Log message missing."}"

  # If stderr is a terminal, print a colored message. Otherwise, print a plain one.
  if [ -t 2 ]; then
    printf "%s%s%s\n" "$(printf "setaf %s\nbold" "$color_code" | tput -S 2>/dev/null)" "$message" "$(tput sgr0 2>/dev/null)" >&2
  else
    printf "%s%s\n" "$level" "$message" >&2
  fi
}
