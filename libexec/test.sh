#!/bin/sh
set -eux
cd /home/person/ltp-install/testscripts
IPV4_LHOST="$1" IPV4_RHOST="$3" IPV6_LHOST="$2" IPV6_RHOST="$4" PASSWD=password RHOST="$3" exec ./network.sh -6mtca
