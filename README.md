<!--
Copyright 2012-2022 Stanislav Senotrusov <stan@senotrusov.com>

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
-->

# 🏔️ Runag

Runag is an attempt to make a shell-only library to deploy linux/macos/windows workstations and servers. Shell was used partially as a way to solve bootstrap problem having a freshly installed system and partially as an exercise in stoicism.

It probably won't help you to deploy some complex cloud setups, but it can configure a pretty solid workstation and bootstrap some simple servers.

You are looking at the repository which mostly contains a standard library. For the examples of what could be accomplished with it please check those other repositories:

  * [🚞 Runagfile to configure my workstation](https://github.com/senotrusov/workstation-runagfile). With one command it creates me a computer that I could use in my daily works without much additional configuration and setup required. It installs and configures software, keys, backup service.

  * [🚋 Example sopkafile with rails and node](https://github.com/senotrusov/example-sopkafile-with-rails-and-node). That I use to deploy my Rails/Node.js projects to Linux servers. I usually put that into the project directory to extend with project-specific stuff.

## One-liner to deploy sopka an a new machine

### Linux
```sh
bash <(wget -qO- https://raw.githubusercontent.com/senotrusov/sopka/main/deploy.sh) [commands...]
```

### MacOS
```sh
bash <(curl -Ssf https://raw.githubusercontent.com/senotrusov/sopka/main/deploy.sh) [commands...]
```

### Commands: 
```sh
add user/repo
run [function-name [function-arguments]]
```

## Offline install

```sh
# create offline install
mkdir sopka-offline-install && cd sopka-offline-install
sopka offline_sopka_install::create_or_update

# install from it
bash deploy-offline.sh
```

## Runagfile

Runag is a collection of functions that you might just load into your bash terminal with `. sopka`, but most of the time you operate with scripts in files. You could source Runag into your scripts with `. sopka` or you could make a file called `sopkafile` and then run `sopka`.

Possible sopkafile locations are:

```sh
./sopkafile.sh
./sopkafile/index.sh

~/.sopkafile.sh
~/.sopkafile/index.sh

~/.sopka/runagfiles/*/index.sh
```

## API docs

I slowly try to document that thing. Please refer to the source code for now.

<!-- API TOC BEGIN -->

### Runag core

* [deploy_script](lib/deploy_script.sh)
* [fail](lib/fail.sh)
* [log](lib/log.sh)
* [menu](lib/menu.sh)
* [sopka](lib/sopka.sh)
* [sopkafile_menu](lib/sopkafile_menu.sh)
* [sopkafile](lib/sopkafile.sh)
* [terminal](lib/terminal.sh)

### General utility

* [archival_snapshots](lib/archival_snapshots.sh)
* [bash](lib/bash.sh)
* [config](lib/config.sh)
* [fs](lib/fs.sh)
* [task](lib/task.sh)

### Interfacing with OS anv VMs

* [apt](lib/apt.sh)
* [linux](lib/linux.sh)
* [macos](lib/macos.sh)
* [os](lib/os.sh)
* [shellrc](lib/shellrc.sh)
* [systemd](lib/systemd.sh)
* [vmware](lib/vmware.sh)

### Managment of keys, passwords, and other secrets

* [bitwarden](lib/bitwarden.sh)
* [checksums](lib/checksums.sh)
* [gpg](lib/gpg.sh)
* [pass](lib/pass.sh)

### Development

* [asdf](lib/asdf.sh)
* [git](lib/git.sh)
* [imagemagick](lib/imagemagick.sh)
* [nodejs](lib/nodejs.sh)
* [nodenv](lib/nodenv.sh)
* [postgresql](lib/postgresql.sh)
* [python](lib/python.sh)
* [rails](lib/rails.sh)
* [rbenv](lib/rbenv.sh)
* [ruby](lib/ruby.sh)

### Networking and access to remote systems

* [cifs](lib/cifs.sh)
* [rsync](lib/rsync.sh)
* [ssh](lib/ssh.sh)
* [syncthing](lib/syncthing.sh)
* [tailscale](lib/tailscale.sh)

### API access to cloud services

* [github](lib/github.sh)
* [leaseweb](lib/leaseweb.sh)
* [letsencrypt](lib/letsencrypt.sh)

### Application deployment

* [app_release](lib/app_release.sh)
* [app_units](lib/app_units.sh)
* [direnv](lib/direnv.sh)

### Desktop applications

* [firefox](lib/firefox.sh)
* [sublime_merge](lib/sublime_merge.sh)
* [sublime_text](lib/sublime_text.sh)
* [vscode](lib/vscode.sh)

### Hard to define a category

* [benchmark](lib/benchmark.sh)

<!-- API TOC END -->

## Environment variables


### General

#### `RUNAG_BIN_PATH`

That variable is here to help you to generate scripts or systemd units that might need to use sopka.
Anywhere you put sopka, the variable will reflect it actual location.
If you put sopka into your home directory them value will be `"${HOME}/.sopka/bin"`.
You could use that file as an executable or you could source that file in your scripts.

#### `RUNAG_UPDATE_SECRETS`

Could be set to `"true"`

#### `RUNAG_VERBOSE`

Could be set to `"true"`


### SSH-related variables

#### `REMOTE_CONTROL_MASTER`

Session sharing is enabled by default in sopka (except when running on Windows).
By default ControlMaster will be set to `"auto"`.
To disable session sharing, set this to `"no"`.

#### `REMOTE_CONTROL_PATH`

Path to the control socket.
By default sopka will use `"${HOME}/.ssh/control-socket.%C"`.

#### `REMOTE_CONTROL_PERSIST`

To disable `ControlPersist` set this to `"no"`.
By default sopka will use `600` seconds.

#### `REMOTE_DIR`

Remote directory to run script in.

#### `REMOTE_ENV`

Space-separated list of environment variable names, to be set in remote script
with the values present in the calling sopka instance at the moment of ssh call.
Example list is: `"FOO BAR QUX"`.
For any provided names (or for absence of them),
sopka will internaly add `"RUNAG_UPDATE_SECRETS RUNAG_TASK_VERBOSE RUNAG_VERBOSE"`.

#### `REMOTE_HOST`

Host name, for example `"example.com"`.
This variable is required to be set.

#### `REMOTE_IDENTITY_FILE`

Path to identity file, for example `"${HOME}/.ssh/id_ed25519"`.
By default sopka will not provide any identity file path so ssh could use it's defaults.

#### `REMOTE_PORT`

Port number. 
By default sopka will not provide any port number so ssh could use it's defaults.

#### `REMOTE_SERVER_ALIVE_INTERVAL`

Will set `ServerAliveInterval`.
By default sopka will set `"20"` as `ServerAliveInterval`.
You could set this to `"0"` to tell ssh to disable server alive messages.
You could set this to `"no"` then sopka will not set that variable at all,
thus ssh could potentially use a value from your ssh config file.

#### `REMOTE_SSH_ARGS`

Additional SSH arguments, array of strings, for example `("-i" "keyfile")`.

#### `REMOTE_UMASK`

Umask for remote commands

#### `REMOTE_USER`

User name.
By default sopka will not provide any user name so ssh could use it's defaults.


### Rsync-related variables

#### `RUNAG_RSYNC_ARGS`

Array of strings, for example `("--archive")`

#### `RUNAG_RSYNC_DELETE_AND_BACKUP`

Could be set to `"true"`

#### `RUNAG_RSYNC_WITHOUT_CHECKSUMS`

Could be set to `"true"`


### Tasks-related variables

#### `RUNAG_TASK_FAIL_DETECTOR`

Could be set to function name. The function will be called with 3 arguments:

```
$1 # stdout_file (path fo file)
$2 # stderr_file (path fo file)
$3 # task_status (integer exit status)
```

The function must return new exit status which will be assumed to be an exit status of the task.

#### `RUNAG_TASK_KEEP_TEMP_FILES`

Could be set to `"true"`

#### `RUNAG_TASK_RECONNECT_ATTEMPTS`

Integer

#### `RUNAG_TASK_RECONNECT_DELAY`

Integer (could be float but that depends on your `sleep` command implementation).

#### `RUNAG_TASK_SSH_JUMP`

Run tasks on remote machine through ssh

#### `RUNAG_TASK_STDERR_FILTER`

Could be set to function name. Function is expected to filter it's input. If function output is empty then stderr will not be displayed.

#### `RUNAG_TASK_VERBOSE`

Could be set to `"true"`


### Internal variables, not to be used by non-library code

```
RUNAG_NODENV_INITIALIZED
RUNAG_RBENV_INITIALIZED
RUNAG_TASK_OMIT_TITLE
RUNAG_TASK_TITLE
```

## Contributing

Please use [ShellCheck](https://www.shellcheck.net/). If it is not integrated into your editor, you could run `npm run lint`.

I mostly follow [Google Shell Style Guide](https://google.github.io/styleguide/shellguide.html).
