## Index

* [apt::update](#aptupdate)
* [apt::dist_upgrade](#aptdistupgrade)
* [apt::install](#aptinstall)
* [apt::autoremove](#aptautoremove)
* [apt::add_source_with_key](#aptaddsourcewithkey)

### apt::update

Perform apt update

### apt::dist_upgrade

Perform apt dist-upgrade

### apt::install

Install package

### apt::autoremove

Perform apt autoremove

### apt::add_source_with_key

Add apt source and key

#### Example

```bash
apt::add_source_with_key "vscode" \
  "https://packages.microsoft.com/repos/code stable main" \
  "https://packages.microsoft.com/keys/microsoft.asc" || softfail || return $?
```

