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
./sopkafile
./sopkafile/index.sh

~/.sopkafile
~/.sopkafile/index.sh

~/.sopka/sopkafiles/*/index.sh
```

## API docs

<!-- API TOC BEGIN -->

### Sopka core

* [deploy-script](docs/lib/deploy-script.md)
* [fail](docs/lib/fail.md)
* [log](docs/lib/log.md)
* [menu](docs/lib/menu.md)
* [sopka-menu](docs/lib/sopka-menu.md)
* [sopka](docs/lib/sopka.md)
* [terminal](docs/lib/terminal.md)

### General utility

* [config](docs/lib/config.md)
* [fs](docs/lib/fs.md)
* [task](docs/lib/task.md)

### Interfacing with OS anv VMs

* [apt](docs/lib/apt.md)
* [linux](docs/lib/linux.md)
* [macos](docs/lib/macos.md)
* [shellrc](docs/lib/shellrc.md)
* [systemd](docs/lib/systemd.md)
* [vmware](docs/lib/vmware.md)

### Managment of keys, passwords, and other secrets

* [bitwarden](docs/lib/bitwarden.md)
* [checksums](docs/lib/checksums.md)
* [gpg](docs/lib/gpg.md)

### Development

* [git](docs/lib/git.md)
* [imagemagick](docs/lib/imagemagick.md)
* [nodejs](docs/lib/nodejs.md)
* [postgresql](docs/lib/postgresql.md)
* [rails](docs/lib/rails.md)
* [ruby](docs/lib/ruby.md)

### Networking and access to remote systems

* [cifs](docs/lib/cifs.md)
* [rsync](docs/lib/rsync.md)
* [ssh](docs/lib/ssh.md)
* [syncthing](docs/lib/syncthing.md)
* [tailscale](docs/lib/tailscale.md)

### API access to cloud services

* [github](docs/lib/github.md)

### Desktop applications

* [firefox](docs/lib/firefox.md)
* [sublime-merge](docs/lib/sublime-merge.md)
* [sublime-text](docs/lib/sublime-text.md)
* [vscode](docs/lib/vscode.md)

### Hard to define a category

* [benchmark](docs/lib/benchmark.md)

<!-- API TOC END -->

## Environment variables


### General

#### `SOPKA_BIN_PATH`

That variable is here to help you to generate scripts or systemd units that might need to use sopka.
Anywhere you put sopka, the variable will reflect it actual location.
If you put sopka into your home dir them value will be `"${HOME}/.sopka/bin"`.
You could use that file as an executable or you could source that file in your scripts.

#### `SOPKA_UPDATE_SECRETS`

Could be set to `"true"`

#### `SOPKA_VERBOSE_TASKS`

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

#### `REMOTE_ENV`

Space-separated list of environment variable names, to be set in remote script
with the values present in the calling sopka instance at the moment of ssh call.
Example list is: `"FOO BAR QUX"`.
For any provided names (or for absence of them),
sopka will internaly add `"SOPKA_UPDATE_SECRETS SOPKA_VERBOSE_TASKS SOPKA_VERBOSE"`.

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
