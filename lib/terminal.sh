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

terminal::color_table() {
  for i in {0..15}; do 
    echo "$(tput setaf "${i}")tput setaf ${i}$(tput sgr 0)"
  done

  for i in {0..15}; do 
    echo "$(tput setab "${i}")tput setab ${i}$(tput sgr 0)"
  done
}

terminal::header() {
  if [ -t 2 ]; then
    echo $'\n'"$(printf "setaf 14\nbold" | tput -S 2>/dev/null)# ${1}$(tput sgr 0 2>/dev/null)"$'\n'
  else
    echo $'\n'"# ${1}"$'\n'
  fi
}
