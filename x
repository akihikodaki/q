#!/usr/bin/env ruby
# frozen_string_literal: true

require 'etc'
require File.join(__dir__, 'lib')

log = nil
q = Q.new do |parser|
  parser.on('-l', '--log [PATH]', String, 'log to file') { log = _1 }
end
qemu = File.join(q.var, 'qemu')
executable = "qemu-system-#{Etc.uname[:machine]}"

base = case Etc.uname[:machine]
       when 'aarch64'
         %W[
           -M virt,accel=kvm -cpu host -serial chardev:chardev
           -drive if=pflash,format=raw,file=#{qemu}/build/pc-bios/edk2-aarch64-code.fd,readonly=on
           -drive if=pflash,format=raw,file=#{q.var}/edk2-arm-vars.fd
         ]
       when 'x86_64'
         %w[
           -M q35,accel=kvm
           -device virtio-serial -device virtconsole,chardev=chardev
         ]
       else
         raise
       end

chardev = if log.nil?
            %w[-chardev stdio,id=chardev,mux=on,signal=off]
          else
            %W[-chardev file,id=chardev,mux=on,path=#{log}]
          end

socket = q.open
socket.close_on_exec = false

q.enter(File.join(qemu, 'build', executable), *base, *chardev, *%W[
  -mon chardev=chardev
  -device virtio-iommu
  -device virtio-net,mac=02:00:00:00:00:#{socket.read(2)},netdev=tap
  -device virtio-net,mac=02:00:00:01:00:00,netdev=hub0port0
  -device #{q.argv[0]},mac=02:00:00:01:00:01,netdev=hub0port1
  -device virtio-net,mac=02:00:00:01:01:00,netdev=hub1port0
  -device #{q.argv[0]},mac=02:00:00:01:01:01,netdev=hub1port1
  -device virtio-net,mac=02:00:00:01:02:00,netdev=hub2port0
  -device #{q.argv[0]},mac=02:00:00:01:02:01,netdev=hub2port1
  -device virtio-net,mac=02:00:00:01:03:00,netdev=hub3port0
  -device #{q.argv[0]},mac=02:00:00:01:03:01,netdev=hub3port1
  -drive if=virtio,format=raw,file=#{q.var}/root.img,file.locking=on
  -netdev tap,script=#{q.libexec}/ifup,downscript=no,id=tap
  -netdev hubport,id=hub0port0,hubid=0 -netdev hubport,id=hub0port1,hubid=0
  -netdev hubport,id=hub1port0,hubid=1 -netdev hubport,id=hub1port1,hubid=1
  -netdev hubport,id=hub2port0,hubid=2 -netdev hubport,id=hub2port1,hubid=2
  -netdev hubport,id=hub3port0,hubid=3 -netdev hubport,id=hub3port1,hubid=3
  -numa node,memdev=ram0 -object memory-backend-ram,size=4G,id=ram0
  -numa node,memdev=ram1 -object memory-backend-ram,size=4G,id=ram1
  -numa cpu,node-id=0,socket-id=0 -numa cpu,node-id=1,socket-id=1
  -nodefaults -nographic -m 8G -smp #{[Etc.nprocessors, 18].max},sockets=2
], *q.argv[1..])
