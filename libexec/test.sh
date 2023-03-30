#!/bin/sh

set -eux
cd /home/person/ltp-install/testscripts
[ "$1" -eq 0 ] || echo "$1" > /sys/class/net/enp0s4/device/sriov_numvfs
ip -4 rule del priority 0 table local
ip -4 rule add priority 1 table local
ip -6 rule del priority 0 table local
ip -6 rule add priority 1 table local
until ip address add 10.0.0.2 dev "$2"
do
  sleep 1
done
ip address add fd00:1:1:1::2 dev "$2"
ip link set "$2" up
ip route add 10.0.0.1 dev "$2"
ip route add fd00:1:1:1::1 dev "$2"
until ip address add 10.0.0.1 dev "$3"
do
  sleep 1
done
ip address add fd00:1:1:1::1 dev "$3"
ip link set "$3" up
ip route add 10.0.0.2 dev "$3"
ip route add fd00:1:1:1::2 dev "$3"
PASSWD=password RHOST=10.0.0.1 exec ./network.sh -6mta
