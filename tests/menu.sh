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

task::test() {
  task::clear || fail
  task::add --header "Section 0"
  task::add --note "Note"
  task::add --comment "list things" ls -la /
  task::add false

  task::add --header "Section 1"
  task::add --header "Section 1.1"
  task::add --note "Note"
  task::add --header "Section 1.2"
  task::add true
  task::add false
  task::add --group task::test::group
  task::add --group task::test::group_without_commands

  task::add --os linux --header "Section 2"
  task::add --os linux true
  task::add --os linux false

  task::add --header "Section 3"
  task::add --header "Section 3.1"
  task::add --note "Note"
  task::add --header "Section 3.2"
  
  task::display
}

task::test::group() {
  task::add --header "Group section 0"
  task::add true
  task::add false
  task::add true
}

task::test::group_without_commands() {
  task::add --header "Group section 0"
  task::add --note "Note"
  task::add --header "Group section 0"
  task::add --note "Note"
  task::add --header "Group section 0"
  task::add --note "Note"
}