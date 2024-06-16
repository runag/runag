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


# Why is this happening?
# I suppose this have something todo with starting other process (hexdump) in the loop
# Maybe it's not the case
# if -t is high enough (0.000001) then all input goes to a terminal
#
# 00000000  1b 5b 44                                          |.[D|
# 00000003
# 00000000  1b 5b 44                                          |.[D|
# 00000003
# ^[[D00000000  1b 5b 44                                          |.[D|
# 00000003
# 00000000  1b 5b 44                                          |.[D|
# 00000003
# 00000000  1b 5b 44                                          |.[D|
# 00000003

while : ; do
  # 0.000001 - character spill
  # 0.005 - trouble
  # 0.01 - slam really hard trouble
  # 0.05 - no trouble observed
  IFS="" read -n 10 -s -r -t 0.000001 input_text
done

# 0.01 - not many doubles
IFS="" read -n 10 -s -r -t 0.01 input_text
if [ ${#input_text} -gt 1 ]; then
  echo double!
fi

menu::read_input::dump() {
  local input_text
  while : ; do
    IFS="" read -n 10 -s -r -t 0.01 input_text
    if [ ${#input_text} -gt 0 ]; then
      printf "%s" "${input_text}" | hexdump -C
    fi
  done
}
