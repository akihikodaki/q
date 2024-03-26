#!/usr/bin/env ruby
# frozen_string_literal: true

require 'etc'

mkosi = if Etc.nprocessors < 18
          %W[--kernel-command-line-extra=isolcpus=#{Etc.nprocessors}-18]
        else
          []
        end

qemu = %W[
  -smp #{[Etc.nprocessors, 18].max},sockets=2
  -device virtio-iommu
  -device pcie-root-port,id=port1,slot=1
  -device pcie-root-port,id=port2,slot=2
  -device pcie-root-port,id=port3,slot=3
  -device pcie-root-port,id=port4,slot=4
  -device pcie-root-port,id=port5,slot=5
  -device virtio-net-pci,addr=0x0.0x0,bus=port1,mac=02:00:00:01:00:00,netdev=hub0port0,multifunction=on
  -device virtio-net-pci,addr=0x0.0x1,bus=port1,mac=02:00:00:01:01:00,netdev=hub1port0
  -device virtio-net-pci,addr=0x0.0x2,bus=port1,mac=02:00:00:01:02:00,netdev=hub2port0
  -device virtio-net-pci,addr=0x0.0x3,bus=port1,mac=02:00:00:01:03:00,netdev=hub3port0
  -device virtio-9p-pci,addr=0x0.0x4,bus=port1,fsdev=fsdev,mount_tag=q
  -device #{ARGV[0]},bus=port2,mac=02:00:00:01:00:01,netdev=hub0port1
  -device #{ARGV[0]},bus=port3,mac=02:00:00:01:01:01,netdev=hub1port1
  -device #{ARGV[0]},bus=port4,mac=02:00:00:01:02:01,netdev=hub2port1
  -device #{ARGV[0]},bus=port5,mac=02:00:00:01:03:01,netdev=hub3port1
  -fsdev local,id=fsdev,path=#{__dir__},security_model=none
  -netdev hubport,id=hub0port0,hubid=0 -netdev hubport,id=hub0port1,hubid=0
  -netdev hubport,id=hub1port0,hubid=1 -netdev hubport,id=hub1port1,hubid=1
  -netdev hubport,id=hub2port0,hubid=2 -netdev hubport,id=hub2port1,hubid=2
  -netdev hubport,id=hub3port0,hubid=3 -netdev hubport,id=hub3port1,hubid=3
  -numa node,memdev=ram0 -object memory-backend-ram,size=7G,id=ram0
  -numa node,memdev=ram1 -object memory-backend-ram,size=7G,id=ram1
  -numa cpu,node-id=0,socket-id=0 -numa cpu,node-id=1,socket-id=1
]

exec({ 'ASAN_OPTIONS' => 'abort_on_error=1',
       'LD_LIBRARY_PATH' => "#{__dir__}/var/fontconfig-build/src:#{ENV['LD_LIBRARY_PATH']}",
       'PATH' => "#{__dir__}/var/qemu/build:#{ENV['PATH']}" },
     'mkosi', *mkosi, 'qemu', *qemu, *ARGV[1..])
