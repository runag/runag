# 🏔️ Sopka

## Sopkafile

Possible sopkafile locations are:

```sh
./sopkafile
./sopkafile/index.sh

~/.sopkafile
~/.sopkafile/index.sh
```

## API docs

* [apt](docs/lib/apt.md)
* [benchmark](docs/lib/benchmark.md)
* [bitwarden](docs/lib/bitwarden.md)
* [borg](docs/lib/borg.md)
* [config](docs/lib/config.md)
* [fs](docs/lib/fs.md)
* [github](docs/lib/github.md)
* [git](docs/lib/git.md)
* [imagemagick](docs/lib/imagemagick.md)
* [linux](docs/lib/linux.md)
* [macos](docs/lib/macos.md)
* [menu](docs/lib/menu.md)
* [nodejs](docs/lib/nodejs.md)
* [nvidia](docs/lib/nvidia.md)
* [postgresql](docs/lib/postgresql.md)
* [rsync](docs/lib/rsync.md)
* [ruby](docs/lib/ruby.md)
* [shellrcd-files](docs/lib/shellrcd-files.md)
* [shellrcd](docs/lib/shellrcd.md)
* [ssh](docs/lib/ssh.md)
* [sublime](docs/lib/sublime.md)
* [syncthing](docs/lib/syncthing.md)
* [systemd](docs/lib/systemd.md)
* [tools](docs/lib/tools.md)
* [ubuntu-desktop](docs/lib/ubuntu-desktop.md)
* [ubuntu-packages](docs/lib/ubuntu-packages.md)
* [ubuntu](docs/lib/ubuntu.md)
* [vmware](docs/lib/vmware.md)
* [vscode](docs/lib/vscode.md)
* [windows](docs/lib/windows.md)

## Bitwarden keys

<!-- # bitwarden-object: see list below -->

```
"? backup passphrase"
"? backup storage"
"? github personal access token"
"? password for ssh private key"
"? ssh private key"
"? ssh public key"
```

## Environment variables

```sh
BITWARDEN_LOGIN
GIT_USER_EMAIL
GIT_USER_NAME
GITHUB_LOGIN
VERBOSE
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
