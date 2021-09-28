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

~/.sopka/sopkafiles/*/index.sh
```

## API docs

* [apt](docs/lib/apt.md)
* [benchmark](docs/lib/benchmark.md)
* [bitwarden](docs/lib/bitwarden.md)
* [checksums](docs/lib/checksums.md)
* [config](docs/lib/config.md)
* [firefox](docs/lib/firefox.md)
* [fs](docs/lib/fs.md)
* [github](docs/lib/github.md)
* [git](docs/lib/git.md)
* [imagemagick](docs/lib/imagemagick.md)
* [keys](docs/lib/keys.md)
* [linux](docs/lib/linux.md)
* [macos](docs/lib/macos.md)
* [menu](docs/lib/menu.md)
* [nodejs](docs/lib/nodejs.md)
* [postgresql](docs/lib/postgresql.md)
* [rails](docs/lib/rails.md)
* [rclone](docs/lib/rclone.md)
* [rsync](docs/lib/rsync.md)
* [ruby](docs/lib/ruby.md)
* [shell](docs/lib/shell.md)
* [sopka](docs/lib/sopka.md)
* [ssh](docs/lib/ssh.md)
* [sublime](docs/lib/sublime.md)
* [syncthing](docs/lib/syncthing.md)
* [systemd](docs/lib/systemd.md)
* [tailscale](docs/lib/tailscale.md)
* [vmware](docs/lib/vmware.md)
* [vscode](docs/lib/vscode.md)

## Environment variables

```sh
# Set by bin/sopka for use in scripts that you might want to generate
SOPKA_BIN_PATH="${HOME}/.sopka/bin"

# Runtime flags
SOPKA_UPDATE_SECRETS=true
SOPKA_VERBOSE_TASKS=true
SOPKA_VERBOSE=true

# SSH-related
SOPKA_REMOTE_HOST="example.com"
SOPKA_REMOTE_PORT="22"
SOPKA_REMOTE_USER="hello"
SOPKA_SEND_ENV=()

# Internal, not to be used in API, referenced here to avoid possible conflicts
SOPKA_APT_LAZY_UPDATE_HAPPENED=true
SOPKA_NODENV_INITIALIZED=true
SOPKA_RBENV_INITIALIZED=true
SOPKA_TASKS_FAIL_ON_ERRORS_IN_RUBYGEMS=true
SOPKA_TASKS_OMIT_TITLES=true
```

# Contributing

Please check shell scripts before commiting any changes with `npm run lint`.

## Style guide

```sh
%q
|| fail
pipestatus
error handling in loops "for, while"
error handling in subshells () {}
error handling in complex commands like ssh "foo" or sudo "foo"
```
