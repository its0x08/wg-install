# wg-install v20211222-4
WireGuard autoinstaller written in Bash

[WireGuard](https://www.wireguard.com) [road warrior](http://en.wikipedia.org/wiki/Road_warrior_%28computing%29) installer for Ubuntu, Debian, CentOS and Fedora!

This script will install automatically the Wireguard server and generate client configuration files for a secure connection.

## Usage command

### Oneliner

`wget https://raw.githubusercontent.com/besmirzanaj/wg-install/master/wg-install.sh -qO wg.sh && bash wg.sh`

### Steps to download and run the scripts:

```bash
git clone https://github.com/besmirzanaj/wg-install.git
cd wg-install
bash wg.sh
```

## Add new client

You can run it again to generate more users after the first run. Reboot your server to apply all settings.

## To start/activate the Wireguard client

`wg-quick up config_name`

## Options

The script can be configured by setting the following environment variables:

* INTERACTIVE - if set to "no", the script will not prompt for user input
* PRIVATE\_SUBNET - private subnet configuration, "10.9.0.0/24" by default
* SERVER\_HOST - public IP address, detected by default
* SERVER\_PORT - listening port, picked random by default
* CLIENT\_DNS - comma serparated DNS servers to use by the client

Copy the file `/root/client-wg0.conf` from a remote server to your local PC 
path `/etc/wireguard/wg0.conf` and run `sudo systemctl start wg-quick@wg0.service` or
you can use the QR code generated by this script to auto-add mobile clients.

## Server/Client status

To check VPN status, run `wg`.
