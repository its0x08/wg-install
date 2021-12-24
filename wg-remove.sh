#!/bin/bash

# wg-remove.sh
# removes any configs from this repos
WG_CONFIG="/etc/wireguard/wg0.conf"
SERVER_PORT=$(grep ListenPort /etc/wireguard/wg0.conf | awk '{print $3}')
PRIVATE_SUBNET=${PRIVATE_SUBNET:-"10.9.0.0/24"}

if [[ "$EUID" -ne 0 ]]; then
    echo "[-] Sorry, you need to run this as root"
    exit
fi

if [[ ! -f "$WG_CONFIG" ]]; then
    echo "[-] There is no config file in $WG_CONFIG"
    exit
fi

# cleaning up
echo "stopping wireguard service and interface"
systemctl stop wg-quick@wg0
systemctl disable wg-quick@wg0
wg-quick down wg0

echo "Restoring Firewall configurations"

if [ -e /etc/centos-release ]; then
    DISTRO="CentOS"
    echo "[i] OS: " $DISTRO
elif [ -e /etc/debian_version ]; then
    DISTRO=$( lsb_release -is )
    echo "[i] OS: " $DISTRO
elif [ -e /etc/system-release ]; then # support for Amazon Linux
    DISTRO=$( lsb_release -is )
    echo "[i] OS: " $DISTRO
else
    echo "[-] Your distribution is not supported (yet)"
    exit
fi

if [ "$DISTRO" == "CentOS" ]; then
        firewall-cmd --zone=public --remove-port=$SERVER_PORT/udp
        firewall-cmd --zone=trusted --remove-source=$PRIVATE_SUBNET
        firewall-cmd --permanent --zone=public --remove-port=$SERVER_PORT/udp
        firewall-cmd --permanent --zone=trusted --remove-source=$PRIVATE_SUBNET
    else
        iptables -D FORWARD -m conntrack --ctstate NEW -s $PRIVATE_SUBNET -m policy --pol none --dir in -j ACCEPT
        iptables -D INPUT -p udp --dport $SERVER_PORT -j ACCEPT
        iptables-save > /etc/iptables/rules.v4
    fi

echo "disabling ip forwarding in kernel"
read -p "Do you want to disable ip forwarding in the kernel? [y/n]: " -e -i "y" DISABLE_FORWARDING
    if [[ "$DISABLE_FORWARDING" == "y" ]] ; then
        sed -i "/s/net.ipv4.ip_forward = 1//g" /etc/sysctl.conf
        sed -i "/s/net.ipv4.conf.all.forwarding = 1//g" /etc/sysctl.conf
        sed -i "/s/net.ipv6.conf.all.forwarding = 1//g" /etc/sysctl.conf
        sysctl -p
    fi

echo "cleaning up config file at $WG_CONFIG"
rm -rf $WG_CONFIG

echo "wireguard config installed from this repo has been cleaned up"