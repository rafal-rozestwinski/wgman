#!/bin/bash
# License: GPLv3 (only).

set -e

ACTION=$1

backup_all() {
	mkdir -p ./.backups/
	tar czf ./.backups/`date +%s`.tar.gz *
}

backup_all

mkdir -p users/

function show_user() {
	U=$2
	if [[ "$U" == "" ]] ; then
	        echo "Param1: username"
	        exit 1
	fi
	cat users/$U/wg-client-$U.conf
}
function show_user_qr() {
	U=$2
	if [[ "$U" == "" ]] ; then
	        echo "Param1: username"
	        exit 1
	fi
	qrencode -t ansiutf8 < users/$U/wg-client-$U.conf
}

function create_user() {
	echo "Create user"
	U=$2
	IP=$3
	if [[ "$U" == "" ]] ; then
	        echo "Param1: username"
	        exit 1
	fi
	if [[ "$IP" == "" ]] ; then
	        echo "Param2: IP"
	        exit 1
	fi

	if [[ `echo "$IP" | cut -d'.' -f4` == "1" ]] ; then
		echo "IPs ending with .1 are not supported"
		exit 3
	fi

	if find users/ -name "$IP" | grep . ; then
		echo "IP has been already allocated!"
		exit 2
	fi

	if find users/ -name "$U" -type d | grep . ; then
		echo "User with such name already exists!"
		exit 4
	fi

	mkdir -vp "users/$U"
	cp ./server/SERVER_ENTRY_TEMPLATE.conf "users/$U/wg-server-$U.conf"
	_SERVER_PUB_KEY=`cat ./server/SERVER_HEADER.conf | grep "# SERVER: PublicKey =" | sed 's%^# SERVER: PublicKey = %%g' `
	_SERVER_EXTERNAL_IP=`cat ./server/EXTERNAL_IP`
	_VPN_SUBNET=`cat ./server/VPN_SUBNET`
	_VPN_EXTRA_MASQUERADE=`cat ./server/VPN_EXTRA_MASQUERADE`
	_VPN_SUBNET_MASK=`cat ./server/VPN_SUBNET_MASK`
	echo $_SERVER_PUB_KEY
	echo $_SERVER_EXTERNAL_IP
	echo $_VPN_SUBNET
	echo $_VPN_SUBNET_MASK
	cp ./server/PEER_CONF_TEMPLATE.conf "users/$U/wg-client-$U.conf"
	cd "users/$U"
		wg genkey | tee client_private_key | wg pubkey > client_public_key
		wg genpsk > client_psk
		_PRIV_KEY=`cat ./client_private_key`
		_PUB_KEY=`cat ./client_public_key`
		_PSK=`cat ./client_psk`
		_ADDR="$IP"
		touch ./$IP
		sed -i "s#^PrivateKey =.*#PrivateKey = $_PRIV_KEY#" "wg-client-$U.conf"
		sed -i "s#^PublicKey =.*#PublicKey = $_SERVER_PUB_KEY#" "wg-client-$U.conf"
		sed -i "s#^PresharedKey =.*#PresharedKey = $_PSK#" "wg-client-$U.conf"
		sed -i "s#^Address =.*#Address = $_ADDR/$_VPN_SUBNET_MASK#" "wg-client-$U.conf"
		sed -i "s#^EndPoint =.*#EndPoint = $_SERVER_EXTERNAL_IP#" "wg-client-$U.conf"
		#sed -i "s#^AllowedIPs =.*#AllowedIPs = $_VPN_SUBNET#" "wg-client-$U.conf"
		sed -i "s#^AllowedIPs =.*#AllowedIPs = $_VPN_SUBNET, $_VPN_EXTRA_MASQUERADE#" "wg-client-$U.conf"

		sed -i "s/^# user:.*/# user: $U/" "wg-server-$U.conf"
		sed -i "s#^PublicKey =.*#PublicKey = $_PUB_KEY#" "wg-server-$U.conf"
		sed -i "s#^PresharedKey =.*#PresharedKey = $_PSK#" "wg-server-$U.conf"
		sed -i "s#^AllowedIPs =.*#AllowedIPs = $IP/32#" "wg-server-$U.conf"
	cd -
	echo "USER CREATION COMPLETE."
}

regen_server_config() {
	echo "Regen server config"
	rm -rf ./tmp/
	mkdir ./tmp/
	cp ./server/SERVER_HEADER.conf ./tmp/wg0.conf
	find ./users/ -name 'wg-server-*.conf' -exec cat {} \; >> ./tmp/wg0.conf
	cp ./tmp/wg0.conf /etc/wireguard/
	systemctl restart wg-quick@wg0 || true
	#wg syncconf wg0 <(wg-quick strip wg0)   # this should not interrupt traffic, but is not working for some reason.
	echo "SERVER CONFIG RELOADED."
}

server_init() {
	EXT_IP_PORT="$2"
	VPN_SUBNET="$3"
	VPN_EXTRA_IFACE="$4"
	VPN_EXTRA_MASQ="$5"
	if [ -d ./server/ ] ; then
		echo "Server already initialized!"
		exit 0
	fi
	if [[ "$EXT_IP_PORT" == "" ]] ; then
	        echo "Param missing: IP:PORT"
		echo "Example: 127.0.0.1:51820  -- UDP, remember!"
	        exit 1
	fi
	if [[ "$VPN_SUBNET" == "" ]] ; then
	        echo "Param missing: VPNSUBNET/MASK"
		echo "Example: 10.60.0.1/24  -- also an addr of wg server (.1)!"
	        exit 1
	fi

	mkdir -vp ./server/
	wg genkey | tee ./server/server_private_key | wg pubkey > ./server/server_public_key
	_SERVER_PRIV_KEY=`cat ./server/server_private_key`
	_SERVER_PUB_KEY=`cat ./server/server_public_key`
	_SERVER_LISTEN_PORT=`echo "$EXT_IP_PORT" | cut -d':' -f2`
	_EXT_ADDR="$EXT_IP_PORT"
	echo "$_EXT_ADDR" > ./server/EXTERNAL_IP
	echo "$VPN_SUBNET" > ./server/VPN_SUBNET
	echo "$VPN_EXTRA_MASQ" > ./server/VPN_EXTRA_MASQUERADE
	echo "$VPN_SUBNET" | cut -d'/' -f2 > ./server/VPN_SUBNET_MASK
	echo "$VPN_SUBNET" | cut -d'/' -f1 > ./server/VPN_SUBNET_ADDR
	echo "$VPN_EXTRA_IFACE" > ./server/VPN_EXTRA_IFACE
	cp -v ./templates/SERVER_HEADER.conf ./server/
	cp -v ./templates/SERVER_ENTRY_TEMPLATE.conf ./server/
	cp -v ./templates/PEER_CONF_TEMPLATE.conf ./server/

	sed -i "s%^# SERVER: .*%# SERVER: PublicKey = $_SERVER_PUB_KEY%" "./server/SERVER_HEADER.conf"
	sed -i "s#^PrivateKey = .*#PrivateKey = $_SERVER_PRIV_KEY#" "./server/SERVER_HEADER.conf"
	sed -i "s#^Address = .*#Address = $VPN_SUBNET#" "./server/SERVER_HEADER.conf"
	sed -i "s#^ListenPort = .*#ListenPort = $_SERVER_LISTEN_PORT#" "./server/SERVER_HEADER.conf"

	if [[ "$VPN_EXTRA_IFACE" == "" ]] ; then
		sed -i "s#^PostUp =.*#PostUp = iptables -I FORWARD -i wg0 -o wg0 -j REJECT ; ip6tables -I FORWARD -i wg0 -o wg0 -j REJECT ;#" "./server/SERVER_HEADER.conf"
	else
		sed -i "s#^PostUp =.*#PostUp = iptables -I FORWARD -i wg0 -o wg0 -j REJECT ; ip6tables -I FORWARD -i wg0 -o wg0 -j REJECT ; iptables -t nat -A POSTROUTING -s $VPN_SUBNET -o $VPN_EXTRA_IFACE -j MASQUERADE#" "./server/SERVER_HEADER.conf"
	fi
	echo "SERVER INIT COMPLETE."
}

if [[ "$ACTION" == "create" ]] ; then
	create_user $@
	regen_server_config
	#show_user $@
	exit 0
fi
if [[ "$ACTION" == "show" ]] ; then
	show_user $@
	exit 0
fi
if [[ "$ACTION" == "qr" ]] ; then
	show_user_qr $@
	exit 0
fi
if [[ "$ACTION" == "delete" ]] ; then
	rm -rvf ./users/$2/
	regen_server_config
	exit 0
fi
if [[ "$ACTION" == "purge" ]] ; then
	rm -rvf ./users/ ./tmp/ ./server/
	exit 0
fi
if [[ "$ACTION" == "regen" ]] ; then
	regen_server_config
	exit 0
fi
if [[ "$ACTION" == "init" ]] ; then
	server_init $@
	exit 0
fi

usage() {
	echo "$0 - manage wireguard user and server configs, on top of wg-quick@wg0"
	echo ""
	echo "INITIALIZE:"
	echo "       $0 init external_ip:port vpn_subnet/mask extra_iface_masquarade 'extra_network/mask, extra_network2/mask'"
	echo "  eg.  $0 init example.com:51820  10.50.0.1/24         eth1            '172.16.20.0/24'"
	echo ""
	echo "If extra_iface_masquarade is provided, traffic will be allowed from/to this interface to VPN clients,"
	echo " so it could be used to open internal company network to VPN clients;"
	echo " subnet of that network shall be passed as extra_networks/masks, so it will be included in the peer configs."
	echo ""
	echo "CREATE USER:"
	echo "      $0 create username <IP>/32"
	echo ""
	echo "DELETE USER:"
	echo "      $0 delete username"
	echo "SHOW USER CONFIG:"
	echo "      $0 show username"
	echo "SHOW QR CODE OF USER CONFIG:"
	echo "      $0 qr username"
	echo ""
	echo "REGENENERATE SERVER CONFIG, JOINING PARTIAL PEERS CONFIG (DONE AUTOMATICALLY AFTER USER CREATE/DELETE):"
	echo "     $0 regen"
	echo "PURGE (remove all users and server configs, but not backups)"
	echo "     $ purge"
	echo ""
	echo "BTW: after each action, in ./.backup/ directory, all configs are backed up."
	echo ""
	echo "(c) 2021 Rafal Rozestwinski, rafal@rozestwinski.com"
	echo ""
	exit 1
}

usage


