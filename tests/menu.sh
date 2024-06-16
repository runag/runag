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

menu::test() {
  menu::clear || fail
  menu::add --header "Section 0"
  menu::add --note "Note"
  menu::add --comment "list things" ls -la /
  menu::add false

  menu::add --header "Section 1"
  menu::add --header "Section 1.1"
  menu::add --note "Note"
  menu::add --header "Section 1.2"
  menu::add true
  menu::add false
  menu::add --menu menu::test::submenu
  menu::add --menu menu::test::submenu_without_commands

  menu::add --os linux --header "Section 2"
  menu::add --os linux true
  menu::add --os linux false

  menu::add --header "Section 3"
  menu::add --header "Section 3.1"
  menu::add --note "Note"
  menu::add --header "Section 3.2"
  
  menu::display
}

menu::test::submenu() {
  menu::add --header "Submenu section 0"
  menu::add true
  menu::add false
  menu::add true
}

menu::test::submenu_without_commands() {
  menu::add --header "Submenu section 0"
  menu::add --note "Note"
  menu::add --header "Submenu section 0"
  menu::add --note "Note"
  menu::add --header "Submenu section 0"
  menu::add --note "Note"
}
