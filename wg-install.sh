#!/bin/bash

# wg-install-dynamic.sh
# run on the first time to configure the server and the first client certificate.
# the following times it will just generate client configs
# Besmir Zanaj - 2020


WG_CONFIG="/etc/wireguard/wg0.conf"

function generate_port
{
    local port=$(shuf -i 35000-65000 -n 1) # lets choose something higher than 35000
    ss -lau | grep $port > /dev/null # check if port already in use

    if [[ $? == 1 ]] ; then
        echo "$port"
    else
        generate_port # pich another port
    fi
}

if [[ "$EUID" -ne 0 ]]; then
    echo "[-] Sorry, you need to run this as root"
    exit
fi

if [[ ! -e /dev/net/tun ]]; then
    echo "[-] The TUN device is not available. You need to enable TUN before running this script"
    exit
fi


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

if [ ! -f "$WG_CONFIG" ]; then
    ### Install server and add default client
    INTERACTIVE=${INTERACTIVE:-yes}
    PRIVATE_SUBNET=${PRIVATE_SUBNET:-"10.9.0.0/24"}
    PRIVATE_SUBNET_MASK=$( echo $PRIVATE_SUBNET | cut -d "/" -f 2 )
    GATEWAY_ADDRESS="${PRIVATE_SUBNET::-4}1"
    read -p "Enter the name of the WAN network interface ([ENTER] set to default: eth0): " WAN_INTERFACE_NAME
    if [ -z $WAN_INTERFACE_NAME ] ; then
        WAN_INTERFACE_NAME="eth0"
    fi
    #GATEWAY_ADDRESS=$(route -n | awk '$1 == "0.0.0.0" {print $2}')

    if [ "$SERVER_HOST" == "" ]; then
        SERVER_HOST=$(curl ifconfig.me -s)
        if [ "$INTERACTIVE" == "yes" ]; then
            read -p "[i] Servers public IP address is $SERVER_HOST  Is that correct? [y/n]: " -e -i "y" CONFIRM
            if [ "$CONFIRM" == "n" ]; then
                echo "[-] Aborted. Use environment variable SERVER_HOST to set the correct public IP address"
                exit
            fi
        fi
    fi

    if [ "$SERVER_PORT" == "" ]; then
        SERVER_PORT=$( generate_port )
    fi

    if [ "$CLIENT_DNS" == "" ]; then
        echo "Which DNS do you want to use with the VPN?"
        echo "   1) Cloudflare"
        echo "   2) Google [Default]"
        echo "   3) OpenDNS (has phishing protection and other security filters)"
        echo "   4) Quad9 (Malware protection)"
        echo "   5) AdGuard DNS (automatically blocks ads)"
        read -p "[?] DNS (1-5)[1]: " -e -i 1 DNS_CHOICE

        case $DNS_CHOICE in
            1)
            CLIENT_DNS="1.1.1.1,1.0.0.1"
            ;;
            2)
            CLIENT_DNS="8.8.8.8,8.8.4.4"
            ;;
            3)
            CLIENT_DNS="208.67.222.222,208.67.220.220"
            ;;
            4)
            CLIENT_DNS="9.9.9.9"
            ;;
            5)
            CLIENT_DNS="94.140.14.14,94.140.15.15"
            ;;
        esac
    fi

    if [ "$DISTRO" == "Ubuntu" ]; then
        add-apt-repository ppa:wireguard/wireguard -y
        apt update
        apt install wireguard qrencode iptables-persistent -y
    elif [ "$DISTRO" == "Debian" ]; then
        echo "deb http://deb.debian.org/debian/ unstable main" > /etc/apt/sources.list.d/unstable.list
        printf 'Package: *\nPin: release a=unstable\nPin-Priority: 90\n' > /etc/apt/preferences.d/limit-unstable
        apt update
        apt install wireguard qrencode iptables-persistent -y
    elif [ "$DISTRO" == "CentOS" ]; then
        yum install -y epel-release https://www.elrepo.org/elrepo-release-7.el7.elrepo.noarch.rpm
        yum install -y yum-plugin-elrepo
        yum install -y kmod-wireguard wireguard-tools qrencode bc firewalld wget curl vim
    elif [ "$DISTRO" == "Amazon" ]; then
        amazon-linux-extras install epel -y
        yum install wireguard-tools bc qrencode -y
    fi

    SERVER_PRIVKEY=$( wg genkey )
    SERVER_PUBKEY=$( echo $SERVER_PRIVKEY | wg pubkey )
    CLIENT_PRIVKEY=$( wg genkey )
    CLIENT_PUBKEY=$( echo $CLIENT_PRIVKEY | wg pubkey )
    CLIENT_ADDRESS="${PRIVATE_SUBNET::-4}3"

    mkdir -p /etc/wireguard
    touch $WG_CONFIG && chmod 600 $WG_CONFIG

    echo "# $PRIVATE_SUBNET $SERVER_HOST:$SERVER_PORT $SERVER_PUBKEY $CLIENT_DNS
[Interface]
Address = $GATEWAY_ADDRESS/$PRIVATE_SUBNET_MASK
ListenPort = $SERVER_PORT
PrivateKey = $SERVER_PRIVKEY
SaveConfig = false
PostUp   = iptables -A FORWARD -i %i -j ACCEPT; iptables -A FORWARD -o %i -j ACCEPT; iptables -t nat -A POSTROUTING -o $WAN_INTERFACE_NAME -j MASQUERADE;
PostDown = iptables -D FORWARD -i %i -j ACCEPT; iptables -D FORWARD -o %i -j ACCEPT; iptables -t nat -D POSTROUTING -o $WAN_INTERFACE_NAME -j MASQUERADE;" > $WG_CONFIG

    echo "# client
[Peer]
PublicKey = $CLIENT_PUBKEY
AllowedIPs = $CLIENT_ADDRESS/32" >> $WG_CONFIG

    echo "[Interface]
PrivateKey = $CLIENT_PRIVKEY
Address = $CLIENT_ADDRESS/$PRIVATE_SUBNET_MASK
DNS = $CLIENT_DNS
[Peer]
PublicKey = $SERVER_PUBKEY
AllowedIPs = 0.0.0.0/0, ::/0
Endpoint = $SERVER_HOST:$SERVER_PORT
PersistentKeepalive = 25" > $HOME/client-wg0.conf
qrencode -t ansiutf8 -l L < $HOME/client-wg0.conf

    echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
    echo "net.ipv4.conf.all.forwarding=1" >> /etc/sysctl.conf
    echo "net.ipv6.conf.all.forwarding=1" >> /etc/sysctl.conf
    sysctl -p

    if [ "$DISTRO" == "CentOS" ]; then
        # Install some basic packages
        yum -y install firewalld
        systemctl enable --now firewalld 
        # Configure Firewall and natting
        firewall-cmd --zone=public --add-port=$SERVER_PORT/udp
        firewall-cmd --zone=trusted --add-source=$PRIVATE_SUBNET
        firewall-cmd --permanent --zone=public --add-port=$SERVER_PORT/udp
        firewall-cmd --permanent --zone=trusted --add-source=$PRIVATE_SUBNET
    else
        iptables -A FORWARD -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
        iptables -A FORWARD -m conntrack --ctstate NEW -s $PRIVATE_SUBNET -m policy --pol none --dir in -j ACCEPT
        iptables -A INPUT -p udp --dport $SERVER_PORT -j ACCEPT
        iptables-save > /etc/iptables/rules.v4
    fi

    systemctl enable wg-quick@wg0.service
    systemctl start wg-quick@wg0.service

    echo "[+] Client config --> $HOME/client-wg0.conf"
    echo "[+] Now reboot the server and enjoy your fresh VPN installation! :^)"
else
    ### Server is installed, add a new client
    CLIENT_NAME="$1"
    if [ "$CLIENT_NAME" == "" ]; then
        echo "[?] Tell me a name for the client config file [no special characters]."
        read -p "[+] Client name: " -e CLIENT_NAME
    fi
    CLIENT_PRIVKEY=$( wg genkey )
    CLIENT_PUBKEY=$( echo $CLIENT_PRIVKEY | wg pubkey )
    PRIVATE_SUBNET=$( head -n1 $WG_CONFIG | awk '{print $2}')
    PRIVATE_SUBNET_MASK=$( echo $PRIVATE_SUBNET | cut -d "/" -f 2 )
    SERVER_ENDPOINT=$( head -n1 $WG_CONFIG | awk '{print $3}')
    SERVER_PUBKEY=$( head -n1 $WG_CONFIG | awk '{print $4}')
    CLIENT_DNS=$( head -n1 $WG_CONFIG | awk '{print $5}')
    LASTIP=$( grep "/32" $WG_CONFIG | tail -n1 | awk '{print $3}' | cut -d "/" -f 1 | cut -d "." -f 4 )
    CLIENT_ADDRESS="${PRIVATE_SUBNET::-4}$((LASTIP+1))"
    echo "# $CLIENT_NAME
[Peer]
PublicKey = $CLIENT_PUBKEY
AllowedIPs = $CLIENT_ADDRESS/32" >> $WG_CONFIG

    echo "[Interface]
PrivateKey = $CLIENT_PRIVKEY
Address = $CLIENT_ADDRESS/$PRIVATE_SUBNET_MASK
DNS = $CLIENT_DNS
[Peer]
PublicKey = $SERVER_PUBKEY
AllowedIPs = 0.0.0.0/0, ::/0 
Endpoint = $SERVER_ENDPOINT
PersistentKeepalive = 25" > $HOME/$CLIENT_NAME-wg0.conf
qrencode -t ansiutf8 -l L < $HOME/$CLIENT_NAME-wg0.conf

    ip address | grep -q wg0 && wg set wg0 peer "$CLIENT_PUBKEY" allowed-ips "$CLIENT_ADDRESS/32"
    echo "[+] Client added, new configuration file --> $HOME/$CLIENT_NAME-wg0.conf"
fi
