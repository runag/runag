<!--
Copyright 2012-2024 Rùnag project contributors

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

# Rùnag

💜 Rùnag is an attempt to make a shell-only library to deploy linux/macos/windows workstations and servers. Shell is used partially as a way to solve bootstrap problem having a freshly installed system and partially as an exercise in stoicism.

It probably won't help you to deploy some complex setups, but it can configure a pretty solid workstation and bootstrap some simple servers.

You are now looking at the repository which mostly contains a standard library. For the examples of what could be accomplished with the library please check "rùnagfiles", that resides in other repositories:

* [💚 Rùnagfile to configure a workstation](https://github.com/runag/workstation-runagfile). It creates a computer that could be used for daily pursuits without much of an additional configuration and setup. It installs and configures software, identities and keys, configures a scheduled backup.


## One-liner to deploy rùnag an a new machine

### Linux
```sh
bash <(wget -qO- https://raw.githubusercontent.com/runag/runag/main/deploy.sh) [commands...]
```

### MacOS
```sh
bash <(curl -Ssf https://raw.githubusercontent.com/runag/runag/main/deploy.sh) [commands...]
```

### Commands: 
```sh
add user/repo
run [function_name [function_arguments]]
```

## Rùnagfile

Possible rùnagfile locations are:

```sh
# in current working directory
./runagfile.sh

# in home directory
~/.runag/runagfiles/*/runagfile.sh
```


## Interactive use or use in scripts besides rùnagfiles

You may load Rùnag into your interactive bash terminal or in your scripts with the `. runag` or `source runag` command.


## API docs

Please refer to the source code for now.

<!-- API TOC BEGIN -->

### Rùnag core

* [fail](lib/fail.sh)
* [log](lib/log.sh)
* [runag](lib/runag.sh)
* [runagfile](lib/runagfile.sh)
* [task](lib/task.sh)

### General utility

* [config](lib/config.sh)
* [dir](lib/dir.sh)
* [file](lib/file.sh)
* [fs](lib/fs.sh)
* [shell](lib/shell.sh)
* [snapshot](lib/snapshot.sh)
* [ui](lib/ui.sh)
* [terminal](lib/terminal.sh)

### Interfacing with OS anv VMs

* [apt](lib/apt.sh)
* [btrfs](lib/btrfs.sh)
* [cross_platform](lib/cross_platform.sh)
* [fstab](lib/fstab.sh)
* [linux](lib/linux.sh)
* [macos](lib/macos.sh)
* [shellfile](lib/shellfile.sh)
* [systemd](lib/systemd.sh)
* [ubuntu](lib/ubuntu.sh)

### Managment of keys, passwords, and other secrets

* [checksum](lib/checksum.sh)
* [gpg](lib/gpg.sh)
* [pass](lib/pass.sh)

### Development

* [asdf](lib/asdf.sh)
* [direnv](lib/direnv.sh)
* [erlang](lib/erlang.sh)
* [git](lib/git.sh)
* [imagemagick](lib/imagemagick.sh)
* [nodejs](lib/nodejs.sh)
* [postgresql](lib/postgresql.sh)
* [python](lib/python.sh)
* [rails](lib/rails.sh)
* [ruby](lib/ruby.sh)

### Networking and access to remote systems

* [aws](lib/aws.sh)
* [cifs](lib/cifs.sh)
* [postfix](lib/postfix.sh)
* [rsync](lib/rsync.sh)
* [ssh-call](lib/ssh-call.sh)
* [ssh](lib/ssh.sh)
* [syncthing](lib/syncthing.sh)
* [tailscale](lib/tailscale.sh)
* [wifi](lib/wifi.sh)

### API access to cloud services

* [github](lib/github.sh)
* [leaseweb](lib/leaseweb.sh)
* [letsencrypt](lib/letsencrypt.sh)

### Application deployment

* [release](lib/release.sh)

### Desktop applications

* [firefox](lib/firefox.sh)
* [sublime-merge](lib/sublime-merge.sh)
* [sublime-text](lib/sublime-text.sh)
* [vscode](lib/vscode.sh)

### Miscellaneous tools

* [benchmark](lib/benchmark.sh)
* [nvidia](lib/nvidia.sh)
* [restic](lib/restic.sh)

<!-- API TOC END -->


## Environment variables
 

### General

#### `RUNAG_VERBOSE`

Could be set to `"true"`

#### `RUNAG_DIST_REPO`

TODO

### SSH-related variables

#### `REMOTE_CONTROL_MASTER`

Session sharing is enabled by default in rùnag (except when running on Windows).
By default ControlMaster will be set to `"auto"`.
To disable session sharing, set this to `"no"`.

#### `REMOTE_CONTROL_PATH`

Path to the control socket.
By default rùnag will use `"${HOME}/.ssh/control-socket.%C"`.

#### `REMOTE_CONTROL_PERSIST`

To disable `ControlPersist` set this to `"no"`.
By default rùnag will use `600` seconds.

#### `REMOTE_DIR`

Remote directory to run script in.

#### `REMOTE_ENV`

String, space-separated list of environment variable names, to be set in remote script with the values present in the calling rùnag instance at the moment of ssh call.
For any provided names (or for absence of them), rùnag will internaly add `"RUNAG_VERBOSE"`.

#### `REMOTE_FORWARD_AGENT`

Could be set to `"true"`

#### `REMOTE_HOST`

Host name, for example `"example.com"`.

#### `REMOTE_IDENTITY_FILE`

Path to identity file, for example `"${HOME}/.ssh/id_ed25519"`.
By default rùnag will not provide any identity file path so ssh could use it's defaults.

#### `REMOTE_KEEP_TEMP_FILES`

Could be set to `"true"`

#### `REMOTE_LOCALE`

String.

#### `REMOTE_PORT`

Port number. 
By default rùnag will not provide any port number so ssh could use it's defaults.

#### `REMOTE_RECONNECT_DELAY`

Integer (could be float but that depends on your `sleep` command implementation).

#### `REMOTE_RECONNECT_TIME_LIMIT`

Seconds, integer

#### `REMOTE_SERVER_ALIVE_INTERVAL`

Will set `ServerAliveInterval`.
By default rùnag will set `"20"` as `ServerAliveInterval`.
You could set this to `"0"` to tell ssh to disable server alive messages.
You could set this to `"no"` then rùnag will not set that variable at all,
thus ssh could potentially use a value from your ssh config file.

#### `REMOTE_UMASK`

Umask for remote commands

#### `REMOTE_USER`

User name.
By default rùnag will not provide any user name so ssh could use it's defaults.


## License

[Apache License, Version 2.0](LICENSE).


## Contributing

Please check [CONTRIBUTING](CONTRIBUTING.md) file for details.
