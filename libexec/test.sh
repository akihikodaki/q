#!/bin/sh
set -eux
cd /home/person/ltp-install/testscripts
IPV4_LHOST="$2/$3" IPV4_RHOST="$7/$8" IPV6_LHOST="$4/$5" IPV6_RHOST="$9/${10}" LHOST_IFACES="$1" PASSWD=password RHOST="$7" RHOST_IFACES="$6" exec ./network.sh -6mrta
