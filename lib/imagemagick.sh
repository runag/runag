#!/usr/bin/env bash

#  Copyright 2012-2022 Runag project contributors
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

imagemagick::set_policy::resource() {
  local name="$1"
  local value="$2"
  local file_path="${4:-"/etc/ImageMagick-6/policy.xml"}"

  sudo sed --in-place "s/^.*\(<policy domain=\"resource\" name=\"${name}\" value=\"\).*\(\"\/>\)$/\1${value}\2/g" "${file_path}" || softfail || return $?
}
