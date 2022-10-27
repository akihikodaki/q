#!/usr/bin/env ruby
# frozen_string_literal: true

require 'etc'
require File.join(__dir__, 'lib')

log = nil
nprocessors = Etc.nprocessors.to_s
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
  -device #{q.argv[0]},mac=02:00:00:00:00:#{socket.read(2)},netdev=netdev
  -drive if=virtio,format=raw,file=#{q.var}/root.img,file.locking=on
  -netdev tap,script=#{q.libexec}/ifup,downscript=no,id=netdev
  -nodefaults -nographic -m 1G -smp #{nprocessors}
], *q.argv[1..])
