# 🏔️ Sopka

## Sopkafile

Possible sopkafile locations are:

```sh
./sopkafile
./sopkafile/index.sh

~/.sopkafile
~/.sopkafile/index.sh
```

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
