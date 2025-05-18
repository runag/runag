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

# ## `grep::filter`
#
# Filters out lines that match the specified patterns using `grep`.
# If no lines are found, it exits with status 0 without triggering an error.
#
# ### Usage
#
# grep::filter ARGUMENTS...
#
# Arguments:
#   ARGUMENTS...  Any valid `grep` arguments or options.
#
# ### Examples
#
# grep::filter -E "DEBUG|TRACE" file1.log file2.log
#
grep::filter () {
  grep -v "$@" || [ $? = 1 ]
}
