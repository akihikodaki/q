#!/bin/sh

set -eux
cd /home/person/ltp-install/testscripts
[ "$1" -eq 0 ] || echo "$1" > /sys/class/net/ens2/device/sriov_numvfs
ip -4 rule del priority 0 table local
ip -4 rule add priority 1 table local
ip -4 rule add to 10.0.0.1 iif lo priority 0 table main
ip -4 rule add to 10.0.0.2 iif lo priority 0 table main
ip -6 rule del priority 0 table local
ip -6 rule add priority 1 table local
ip -6 rule add to fd00:1:1:1::1 iif lo priority 0 table main
ip -6 rule add to fd00:1:1:1::2 iif lo priority 0 table main
sysctl "net.ipv6.conf.$2.addr_gen_mode=0"
ip address add 10.0.0.2 dev "$2"
ip address add fd00:1:1:1::2 dev "$2"
ip link set "$2" up
ip route del fd00:1:1:1::2
ip route add 10.0.0.1 dev "$2"
sysctl "net.ipv6.conf.$3.addr_gen_mode=0"
ip address add 10.0.0.1 dev "$3"
ip address add fd00:1:1:1::1 dev "$3"
ip link set "$3" up
ip route del fd00:1:1:1::1
ip route add 10.0.0.2 dev "$3"
ip route add fd00:1:1:1::1 dev "$2"
ip route add fd00:1:1:1::2 dev "$3"
ip link set ens2 up
for suffix in 1 2
do
  until ping -6 -c 1 "fd00:1:1:1::$suffix"
  do
    :
  done
done
PASSWD=password RHOST=10.0.0.1 exec ./network.sh -6mta
