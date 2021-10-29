#!/usr/bin/env bash

#  Copyright 2012-2021 Stanislav Senotrusov <stan@senotrusov.com>
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

rails::get-database-config() {
  ruby <(rails::get-database-config::ruby-script) "$1" || softfail "Unable to get database config from ruby" || return $?
}

rails::get-database-config::ruby-script(){
  cat << RUBY
    require "yaml"

    key=ARGV[0]

    exit 1 unless key
    exit 1 if key.empty?
    
    config = YAML.load_file "config/database.yml"

    exit 1 unless config.is_a?(Hash)

    env_config = config[ENV["RAILS_ENV"] || "development"]

    exit 1 unless env_config.is_a?(Hash)

    value = env_config[key]

    exit 1 unless value
    exit 1 if value.empty?

    puts value
RUBY
}
