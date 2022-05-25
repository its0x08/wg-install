# wg-install v0.0.3-beta
WireGuard autoinstaller written in Bash

[WireGuard](https://www.wireguard.com) [road warrior](http://en.wikipedia.org/wiki/Road_warrior_%28computing%29) installer for Ubuntu, Debian, CentOS and Fedora!

This script will install automatically the Wireguard server and generate client configuration files for a secure connection.

![Visitors](https://api.visitorbadge.io/api/visitors?path=https%3A%2F%2Fgithub.com%2Fits0x08%2Fwg-install&countColor=%232ccce4&style=flat-square)
[![Semgrep](https://github.com/its0x08/wg-install/actions/workflows/semgrep.yml/badge.svg)](https://github.com/its0x08/wg-install/actions/workflows/semgrep.yml)
[![Codacy Security Scan](https://github.com/its0x08/wg-install/actions/workflows/codacy.yml/badge.svg)](https://github.com/its0x08/wg-install/actions/workflows/codacy.yml)


## Usage command

### Oneliner:
```bash
wget http://git.io/Jff1k -qO wg.sh && bash wg.sh
```

### Steps to download and run the scripts:
```bash
git clone https://github.com/its0x08/wg-install.git
cd wg-install
bash wg.sh
```

## Add new client or remove and uninstall WireGuard
You can run it again to generate more users after the first run, or remove WireGuard. Reboot your server to apply all settings.

## To start/activate the Wireguard client:
```bash
wg-quick up config_name
```

## Options:

The script can be configured by setting the following environment variables:

* INTERACTIVE - if set to "no", the script will not prompt for user input
* PRIVATE_SUBNET - private subnet configuration, "10.9.0.0/24" by default
* SERVER_HOST - public IP address, detected by default
* SERVER_PORT - listening port, picked random by default
* CLIENT_DNS - comma serparated DNS servers to use by the client
* ADD_REMOVE - set to `1` to remove WireGuard or `2` to add new users


Copy the file `/root/client-wg0.conf` from a remote server to your local PC
path `/etc/wireguard/wg0.conf` and run `sudo systemctl start wg-quick@wg0.service` or
you can use the QR code generated by this script to auto-add mobile clients.

## Server/Client status:
To check VPN status, run `wg`.

# Pull Requests are appreciated

## Enjoy it !

#### Note: dont forget to report bugs please!!
