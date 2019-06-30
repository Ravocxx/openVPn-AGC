#!/bin/sh

if [ "$script_type" == "up" -o "$script_type" == "down" ]
then
	/rom/openvpn/updown.sh
fi

if [ "$route_gateway_1" != "" ]
then
	VPN_IP_LIST=$(nvram get vpn_client1_ip_list)
	VPN_TBL=$(nvram get vpn_tbl_1)
	if [ "$VPN_TBL" == "" ]
	then
		VPN_TBL=101
	fi
elif [ "$route_gateway_2" != "" ]
then
	VPN_IP_LIST=$(nvram get vpn_client2_ip_list)
	VPN_TBL=$(nvram get vpn_tbl_2)
	if [ "$VPN_TBL" == "" ]
	then
		VPN_TBL=102
	fi
fi

export VPN_GW VPN_IP VPN_TBL

# delete rules for IPs not on list
IP_LIST=`ip rule show|awk '$2 == "from" && $4=="lookup" && $5==ENVIRON["VPN_TBL"] {print $3}'`
for IP in $IP_LIST
do
	DEL_IP="y"
	for VPN_IP in $VPN_IP_LIST
	do
		if [ "$IP" == "$VPN_IP" ]
		then
			DEL_IP=
		fi
	done

	if [ "$DEL_IP" == "y" ]
	then
		ip rule del from $IP table $VPN_TBL
	fi
done

# add rules for any new IPs
for VPN_IP in $VPN_IP_LIST
do
	IP_LIST=`ip rule show|awk '$2=="from" && $3==ENVIRON["VPN_IP"] && $4=="lookup" && $5==ENVIRON["VPN_TBL"] {print $3}'`
	if [ "$IP_LIST" == "" ]
	then
		ip rule add from $VPN_IP table $VPN_TBL
	fi
done

if [ "$script_type" == "route-up" ]
then
	VPN_GW=$route_vpn_gateway
else
	VPN_GW=127.0.0.1  # if VPN down, block VPN IPs from WAN
fi

# delete VPN routes
NET_LIST=`ip route show|awk '$2=="via" && $3==ENVIRON["VPN_GW"] && $4=="dev" && $5==ENVIRON["dev"] {print $1}'`
for NET in $NET_LIST
do
	ip route del $NET dev $dev 
done

# route VPN IPs thru VPN gateway
if [ "$VPN_IP_LIST" != "" ]
then
	ip route del default table $VPN_TBL
	ip route add default via $VPN_GW table $VPN_TBL
	logger "Routing $VPN_IP_LIST via VPN gateway $VPN_GW"
fi

# route other IPs thru WAN gateway
if [ "$route_net_gateway" != "" ]
then
	ip route del default
	ip route add default via $route_net_gateway
fi

ip route flush cache

exit 0
