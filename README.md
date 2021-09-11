# 🏔️ Sopka

## Linux

```sh
bash <(wget -qO- https://raw.githubusercontent.com/senotrusov/sopka/main/deploy.sh) [user/repo] [function-name [function-arguments]]
bash <(wget -qO- https://raw.githubusercontent.com/senotrusov/sopka/main/deploy.sh) -- [function-name [function-arguments]]
```

## MacOS

```sh
bash <(curl -Ssf https://raw.githubusercontent.com/senotrusov/sopka/main/deploy.sh) [user/repo] [function-name [function-arguments]]
bash <(curl -Ssf https://raw.githubusercontent.com/senotrusov/sopka/main/deploy.sh) -- [function-name [function-arguments]]
```

## Sopkafile

Possible sopkafile locations are:

```sh
./sopkafile
./sopkafile/index.sh

~/.sopkafile
~/.sopkafile/index.sh

~/.sopka/files/*/index.sh
```

## API docs

* [apt](docs/lib/apt.md)
* [benchmark](docs/lib/benchmark.md)
* [bitwarden](docs/lib/bitwarden.md)
* [config](docs/lib/config.md)
* [firefox](docs/lib/firefox.md)
* [fs](docs/lib/fs.md)
* [git](docs/lib/git.md)
* [github](docs/lib/github.md)
* [imagemagick](docs/lib/imagemagick.md)
* [linux](docs/lib/linux.md)
* [macos](docs/lib/macos.md)
* [menu](docs/lib/menu.md)
* [nodejs](docs/lib/nodejs.md)
* [postgresql](docs/lib/postgresql.md)
* [rails](docs/lib/rails.md)
* [rclone](docs/lib/rclone.md)
* [restic](docs/lib/restic.md)
* [rsync](docs/lib/rsync.md)
* [ruby](docs/lib/ruby.md)
* [shell](docs/lib/shell.md)
* [ssh](docs/lib/ssh.md)
* [sublime](docs/lib/sublime.md)
* [syncthing](docs/lib/syncthing.md)
* [systemd](docs/lib/systemd.md)
* [tailscale](docs/lib/tailscale.md)
* [tools](docs/lib/tools.md)
* [vmware](docs/lib/vmware.md)
* [vscode](docs/lib/vscode.md)

## Environment variables

```sh
# set by bin/sopka for use in scripts that you might want to generate
SOPKA_BIN_PATH="${HOME}/.sopka/bin"

# internal
SOPKA_APT_LAZY_UPDATE_HAPPENED=true
SOPKA_NODENV_INITIALIZED=true
SOPKA_RBENV_INITIALIZED=true

# ssh-related
SOPKA_REMOTE_HOST="example.com"
SOPKA_REMOTE_PORT="22"
SOPKA_REMOTE_USER="hello"
SOPKA_SEND_ENV=()

# runtime flags
SOPKA_UPDATE_SECRETS=true
SOPKA_VERBOSE=true
```

# Contributing

## Please check shell scripts before commiting any changes
```sh
test/run-code-checks.sh
```

## Style guide

```sh
%q
|| fail
pipestatus
error handling in loops "for, while"
error handling in subshells () {}
error handling in complex commands like ssh "foo" or sudo "foo"
use shellcheck
```
