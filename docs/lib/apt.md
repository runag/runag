## Index

* [apt::lazy_update](#aptlazy_update)
* [apt::lazy_update_and_dist_upgrade](#aptlazy_update_and_dist_upgrade)
* [apt::update](#aptupdate)
* [apt::dist_upgrade](#aptdist_upgrade)
* [apt::install](#aptinstall)
* [apt::autoremove](#aptautoremove)
* [apt::add_key_and_source](#aptadd_key_and_source)

### apt::lazy_update

Perform apt update once per script run

### apt::lazy_update_and_dist_upgrade

Perform apt update once per script run, and then perform apt dist-upgrade

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

