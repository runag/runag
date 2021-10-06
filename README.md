# 🏔️ Sopka

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
* [shell](docs/lib/shell.md)
* [systemd](docs/lib/systemd.md)
* [vmware](docs/lib/vmware.md)

### Managment of keys, passwords, and other secrets

* [bitwarden](docs/lib/bitwarden.md)
* [checksums](docs/lib/checksums.md)
* [keys](docs/lib/keys.md)

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

```sh
# That variable is here to help you to generate scripts or systemd units that might need to use sopka
SOPKA_BIN_PATH="${HOME}/.sopka/bin" # if you put sopka somewhere else, then value will be different

# Runtime flags
SOPKA_UPDATE_SECRETS=true
SOPKA_VERBOSE_TASKS=true
SOPKA_VERBOSE=true

# SSH-related
SOPKA_REMOTE_HOST="example.com"
SOPKA_REMOTE_PORT="22"
SOPKA_REMOTE_USER="hello"
SOPKA_SEND_ENV=()

# Internal, not to be used by non-library code
SOPKA_APT_LAZY_UPDATE_HAPPENED=true
SOPKA_NODENV_INITIALIZED=true
SOPKA_RBENV_INITIALIZED=true
SOPKA_TASK_FAIL_ON_ERROR_IN_RUBYGEMS=true
SOPKA_TASK_OMIT_TITLE=true
SOPKA_TASK_TITLE="task title"
```

# Contributing

Please check shell scripts before commiting any changes with `npm run lint`.
