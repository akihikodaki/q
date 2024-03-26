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
  -fsdev local,id=fsdev,path=#{__dir__},security_model=none
  -device pcie-root-port,id=port1,slot=1
  -device virtio-9p-pci,addr=0x0.0x0,bus=port1,fsdev=fsdev,mount_tag=q,multifunction=on
]

exec({
       'ASAN_OPTIONS' => 'abort_on_error=1',
       'LD_LIBRARY_PATH' => "#{__dir__}/var/fontconfig-build/src:#{ENV['LD_LIBRARY_PATH']}",
       'PATH' => "#{__dir__}/var/qemu/build:#{ENV['PATH']}"
     }, 'mkosi', *mkosi, 'qemu', *qemu, *ARGV)
