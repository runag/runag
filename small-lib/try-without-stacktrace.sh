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

# Runs a command and prints a warning to stderr if it fails.
# Usage: try_warn ls /nonexistent_directory
try_warn() {
  "$@" # Run the command, passing all arguments to it
  local status=$? # Capture the exit status of the command
  if [ $status -ne 0 ]; then
    echo "Warning: Command failed with exit status $status: $*" >&2
  fi
  return $status
}

# Runs a command and exits the script if it fails.
# Usage: try_exit grep "root" /etc/shadow
try_exit() {
  "$@" # Run the command, passing all arguments to it
  local status=$? # Capture the exit status of the command
  if [ $status -ne 0 ]; then
    echo "Error: Command failed with exit status $status: $*" >&2
    exit $status # Terminate the script with the same exit code
  fi
  return 0
}
