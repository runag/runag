## Index

* [apt::update](#aptupdate)
* [apt::dist_upgrade](#aptdist_upgrade)
* [apt::install](#aptinstall)
* [apt::autoremove](#aptautoremove)
* [apt::add_key_and_source](#aptadd_key_and_source)

### apt::update

Perform apt update

### apt::dist_upgrade

Perform apt dist-upgrade

### apt::install

Install package

### apt::autoremove

Perform apt autoremove

### apt::add_key_and_source

Add apt source and key

#### Example

```bash
apt::add_key_and_source "https://dl.yarnpkg.com/debian/pubkey.gpg" "deb https://dl.yarnpkg.com/debian/ stable main" "yarn" | fail
```

#### Arguments

* **$1** (string): key url
* **$2** (string): source string
* **$3** (string): source name for sources.list.d

