#!/bin/sh
set -eux
cd /home/person/ltp-install/testscripts
IPV4_LHOST="$2" IPV4_RHOST="$5" IPV6_LHOST="$3" IPV6_RHOST="$6" LHOST_IFACES="$1" PASSWD=password RHOST="$5" RHOST_IFACES="$4" exec ./network.sh -6mrta
