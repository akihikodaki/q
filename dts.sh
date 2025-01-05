#!/bin/sh

set -e
cd /mnt/dpdk/dts
meson setup --reconfigure -Dplatform=generic /mnt/dpdk /mnt/var/dpdk
meson compile -C /mnt/var/dpdk
ip link set ens1f0 up
ip link set ens1f1 up
modprobe vfio-pci
sysctl vm.nr_hugepages=512
poetry run ./main.py --config-file /mnt/dts.yaml --output "/mnt/$1/output"
