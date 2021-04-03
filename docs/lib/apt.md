## Index

* [apt::lazy-update()](#aptlazy-update)
* [apt::update()](#aptupdate)
* [apt::dist-upgrade()](#aptdist-upgrade)
* [apt::install()](#aptinstall)
* [apt::autoremove()](#aptautoremove)
* [apt::add-key-and-source()](#aptadd-key-and-source)

### apt::lazy-update()

Perform apt update once

### apt::update()

Perform apt update

### apt::dist-upgrade()

Perform apt dist-upgrade

### apt::install()

Install package

### apt::autoremove()

Perform apt autoremove

### apt::add-key-and-source()

Add apt source and key

#### Example

```bash
apt::add-key-and-source "https://dl.yarnpkg.com/debian/pubkey.gpg" "deb https://dl.yarnpkg.com/debian/ stable main" "yarn"
```

#### Arguments

* **$1** (string): key url
* **$2** (string): source string
* **$3** (string): source name

