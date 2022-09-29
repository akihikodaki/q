#!/usr/bin/env ruby
# frozen_string_literal: true

require 'etc'
require 'socket'

nprocessors = Etc.nprocessors.to_s
qemu = File.join(__dir__, 'var', 'qemu')
system 'make', '-C', qemu, '-j', nprocessors, 'qemu-system-x86_64', exception: true

socket = UNIXSocket.new(File.join(__dir__, 'var', 'sock'))
socket.close_on_exec = false

exec(*%W[
  #{__dir__}/e #{qemu}/build/qemu-system-x86_64 -M q35,accel=kvm
  -chardev stdio,id=stdio,signal=off
  -device #{ARGV[0]},mac=02:00:00:00:00:#{socket.read(2)},netdev=netdev
  -device virtio-serial -device virtconsole,chardev=stdio
  -drive if=virtio,format=raw,file=#{__dir__}/var/root.img,file.locking=on
  -netdev tap,script=#{__dir__}/libexec/ifup,downscript=no,id=netdev
  -nodefaults -nographic -m 4G -smp #{nprocessors}
], *ARGV[1..])
