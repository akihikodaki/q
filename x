#!/usr/bin/env ruby
# frozen_string_literal: true

require 'etc'
require 'socket'

nprocessors = Etc.nprocessors.to_s
qemu = File.join(__dir__, 'var', 'qemu')
executable = "qemu-system-#{Etc.uname[:machine]}"

base = case Etc.uname[:machine]
       when 'aarch64'
         %W[
           -M virt,accel=kvm -cpu host -serial mon:stdio
           -drive if=pflash,format=raw,file=#{qemu}/build/pc-bios/edk2-aarch64-code.fd,readonly=on
           -drive if=pflash,format=raw,file=#{__dir__}/var/edk2-arm-vars.fd
         ]
       when 'x86_64'
         %W[
           -M q35,accel=kvm -mon chardev=stdio
           -chardev stdio,id=stdio,mux=on,signal=off
           -device virtio-serial -device virtconsole,chardev=stdio
         ]
       else
         raise
       end

system 'make', '-C', qemu, '-j', nprocessors, executable, exception: true

socket = UNIXSocket.new(File.join(__dir__, 'var', 'sock'))
socket.close_on_exec = false

exec(File.join(__dir__, 'e'), File.join(qemu, 'build', executable), *base, *%W[
  -device #{ARGV[0]},mac=02:00:00:00:00:#{socket.read(2)},netdev=netdev
  -drive if=virtio,format=raw,file=#{__dir__}/var/root.img,file.locking=on
  -netdev tap,script=#{__dir__}/libexec/ifup,downscript=no,id=netdev
  -nodefaults -nographic -m 4G -smp #{nprocessors}
], *ARGV[1..])
