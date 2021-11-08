# 🏔️ Sopka

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

## Sopkafile

Possible sopkafile locations are:

```sh
./sopkafile.sh
./sopkafile/index.sh

~/.sopkafile.sh
~/.sopkafile/index.sh

~/.sopka/sopkafiles/*/index.sh
```

## API docs

Please refer to the source code for now.

<!-- API TOC BEGIN -->

### Sopka core

* [deploy-script](lib/deploy-script.sh)
* [fail](lib/fail.sh)
* [log](lib/log.sh)
* [menu](lib/menu.sh)
* [sopka-menu](lib/sopka-menu.sh)
* [sopka](lib/sopka.sh)
* [terminal](lib/terminal.sh)

### General utility

* [config](lib/config.sh)
* [fs](lib/fs.sh)
* [task](lib/task.sh)

### Interfacing with OS anv VMs

* [apt](lib/apt.sh)
* [linux](lib/linux.sh)
* [macos](lib/macos.sh)
* [shellrc](lib/shellrc.sh)
* [systemd](lib/systemd.sh)
* [vmware](lib/vmware.sh)

### Managment of keys, passwords, and other secrets

* [bitwarden](lib/bitwarden.sh)
* [checksums](lib/checksums.sh)
* [gpg](lib/gpg.sh)

### Development

* [git](lib/git.sh)
* [imagemagick](lib/imagemagick.sh)
* [nodejs](lib/nodejs.sh)
* [postgresql](lib/postgresql.sh)
* [python](lib/python.sh)
* [rails](lib/rails.sh)
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

### Application deployment

* [app-env](lib/app-env.sh)
* [app-release](lib/app-release.sh)

### Desktop applications

* [firefox](lib/firefox.sh)
* [sublime-merge](lib/sublime-merge.sh)
* [sublime-text](lib/sublime-text.sh)
* [vscode](lib/vscode.sh)

### Hard to define a category

* [benchmark](lib/benchmark.sh)

<!-- API TOC END -->

## Environment variables


### General

#### `SOPKA_BIN_PATH`

That variable is here to help you to generate scripts or systemd units that might need to use sopka.
Anywhere you put sopka, the variable will reflect it actual location.
If you put sopka into your home directory them value will be `"${HOME}/.sopka/bin"`.
You could use that file as an executable or you could source that file in your scripts.

#### `SOPKA_UPDATE_SECRETS`

Could be set to `"true"`

#### `SOPKA_VERBOSE`

Could be set to `"true"`


### SSH-related

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
sopka will internaly add `"SOPKA_UPDATE_SECRETS SOPKA_TASK_VERBOSE SOPKA_VERBOSE"`.

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


### rsync-related

#### `SOPKA_RSYNC_ARGS`

Array of strings, for example `("--archive")`

#### `SOPKA_RSYNC_DELETE_AND_BACKUP`

Could be set to `"true"`

#### `SOPKA_RSYNC_WITHOUT_CHECKSUMS`

Could be set to `"true"`

#### `SOPKA_TASK_FAIL_DETECTOR`

Could be set to function name. The function will be called with 3 arguments:

```
$1 # stdoutFile (path fo file)
$2 # stderrFile (path fo file)
$3 # taskStatus (integer exit status)
```

The function must return new exit status which will be assumed to be an exit status of the task.

#### `SOPKA_TASK_KEEP_TEMP_FILES`

Could be set to `"true"`

#### `SOPKA_TASK_RECONNECT_ATTEMPTS`

Integer

#### `SOPKA_TASK_RECONNECT_DELAY`

Integer (could be float but that depends on your `sleep` command implementation).

#### `SOPKA_TASK_SSH_JUMP`

Run tasks on remote machine through ssh

#### `SOPKA_TASK_STDERR_FILTER`

Could be set to function name. Function is expected to filter it's input. If function output is empty then stderr will not be displayed.

#### `SOPKA_TASK_VERBOSE`

Could be set to `"true"`

### Internal variables, not to be used by non-library code

```
SOPKA_APT_LAZY_UPDATE_HAPPENED
SOPKA_NODENV_INITIALIZED
SOPKA_RBENV_INITIALIZED
SOPKA_TASK_OMIT_TITLE
SOPKA_TASK_TITLE
```

## Contributing

Please check shell scripts before commiting any changes with `npm run lint`.
