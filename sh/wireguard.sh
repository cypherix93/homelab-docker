#!/bin/bash

# From: https://github.com/BrodyBuster/docker-wireguard-vpn

# Name of the docker network to route through wireguard
# This network will be created if it does not exist
DOCKER_NET_NAME="wireguard-vpn-wg0"
# Subnet to use for this docker network
DOCKER_NET_SUBNET="10.30.0.0/16"
# Name of wireguard interface to create
DEV_NAME="wg0"
# Path to wireguard conf file
WG_CONF_PATH="/volume1/docker/wireguard/config/$DEV_NAME.conf"
# Dedicated IP assigned by your VPN provider. Leave as is, if you're not using a dedicated IP
DEDICATED_IP=""

##########################################################################################
# Get configs from wireguard configs
INTERFACE_IP=$(grep Address $WG_CONF_PATH | awk '{print $3}' | cut -d/ -f1)
INTERFACE_DNS=$(grep DNS $WG_CONF_PATH | awk '{print $3}' | cut -d/ -f1)
INTERFACE_MTU=$(grep MTU $WG_CONF_PATH | awk '{print $3}' | cut -d/ -f1)

if_check () {
    CMD=$($1)
    CHECK=$2
    RETVAL=$?
    if [ $RETVAL -ne 0 ]; then
            echo "fail"
            exit 1
    fi
    echo "ok:     $1"
}

while_check () {
    RETVAL=$?
    while [ $RETVAL -ne 0 ]; do
            CMD=$($1)
            echo "        Route/Rule/Network Does Not Exist. Creating ..."
            RETVAL=$?
    done
    echo "ok:     $1"
}

status () {
    # Check to see if using DEDICATED IP
    if [ -z "$DEDICATED_IP" ]
    then
        ENDPOINT_IP=$(grep Endpoint $WG_CONF_PATH | awk '{print $3}' | cut -d: -f1)
    else
        ENDPOINT_IP=$DEDICATED_IP
    fi

    # check blackhole
    CMD="ip route add blackhole default metric 3 table 200"
    CHECK=$(ip route show table 200 2>/dev/null | grep -w "blackhole")
    while_check "$CMD" "$CHECK"

    VPNIP=$(docker run -ti --rm --net=$DOCKER_NET_NAME appropriate/curl https://api.ipify.org)
    IP=$(curl --silent https://api.ipify.org)

    echo "status: Endpoint IP: $ENDPOINT_IP"
    echo "status: Container IP: $VPNIP"
    echo "status: Host IP: $IP"

    if [[ $VPNIP == *"Could not resolve host"*  ]]; then
        echo "ok:     Not Connected to Endpoint: Blackhole active"
    elif [[ $VPNIP == $ENDPOINT_IP ]]; then
        echo "ok:     Connected to $ENDPOINT_IP"
    elif [[ $VPNIP == $IP ]]; then
        echo "failed: Not Connected to Endpoint: Blackhole NOT active!"
    fi
}

up () {
    # check for conf file
    if [ ! -f "$WG_CONF_PATH" ]; then
        echo -e "failed: no conf file found at $WG_CONF_PATH"
        exit 1
    fi
    echo -e "ok:     conf file exists"

    # add wireguard interface
    CMD="ip link add $DEV_NAME type wireguard"
    CHECK=$(ip addr | grep $DEV_NAME)
    if_check "$CMD" "$CHECK"

    # set wireguard conf
    CMD="wg setconf $DEV_NAME $WG_CONF_PATH"
    CHECK=$(wg showconf $DEV_NAME 2>/dev/null)
    if_check "$CMD" "$CHECK"

    # assign ip to wireguard interface
    CMD="ip addr add $INTERFACE_IP dev $DEV_NAME"
    CHECK=$(ip addr | grep "$INTERFACE_IP")
    if_check "$CMD" "$CHECK"

    # set sysctl
    CMD="sysctl -w net.ipv4.conf.all.rp_filter=2"
    if_check "$CMD"

    # set mtu for wireguard interface
    CMD="ip link set mtu $INTERFACE_MTU up dev $DEV_NAME"
    if_check "$CMD"

    # bring wireguard interface up
    CMD="ip link set up dev $DEV_NAME"
    CHECK=$(ip addr | grep $DEV_NAME | grep UP)
    if_check "$CMD" "$CHECK"

    # create docker network
    CMD="docker network create $DOCKER_NET_NAME -d bridge --scope swarm --attachable --subnet $DOCKER_NET_SUBNET -o "com.docker.network.driver.mtu"="$INTERFACE_MTU""
    CHECK=$(docker network inspect $DOCKER_NET_NAME > /dev/null 2>&1)
    while_check "$CMD" "$CHECK"

    # add table 200
    CMD="ip rule add from $DOCKER_NET_SUBNET table 200"
    CHECK=$(ip rule show | grep -w "lookup 200")
    while_check "$CMD" "$CHECK"

    # add blackhole
    CMD="ip route add blackhole default metric 3 table 200"
    CHECK=$(ip route show table 200 2>/dev/null | grep -w "blackhole")
    while_check "$CMD" "$CHECK"

    # add default route for table 200
    CMD="ip route add default via $INTERFACE_IP metric 2 table 200"
    CHECK=$(ip route show table 200 2>/dev/null | grep -w "$INTERFACE_IP")
    while_check "$CMD" "$CHECK"

    # add local lan route
    CMD="ip rule add table main suppress_prefixlength 0"
    CHECK=$(ip rule show | grep -w "suppress_prefixlength")
    while_check "$CMD" "$CHECK"

    # show wg status
    wg show $DEV_NAME
}

down () {
    # del docker network
    CMD="docker network rm $DOCKER_NET_NAME"
    if_check "$CMD"

    # del wireguard interface
    CMD="ip link del $DEV_NAME"
    CHECK=$(ip addr | grep $DEV_NAME)
    if_check "$CMD" "$CHECK"

    # add table 200
    CMD="ip rule add from $DOCKER_NET_SUBNET table 200"
    CHECK=$(ip rule show | grep -w "lookup 200")
    while_check "$CMD" "$CHECK"

    # add blackhole
    CMD="ip route add blackhole default metric 3 table 200"
    CHECK=$(ip route show table 200 2>/dev/null | grep -w "blackhole")
    while_check "$CMD" "$CHECK"
}

command="$1"
shift

case "$command" in
    up) up "$@" ;;
    down) down "$@" ;;
    status) status "$@" ;;
    *) echo "Usage: $0 up|down|status" >&2; exit 1 ;;
esac

