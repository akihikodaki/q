#!/usr/bin/env ruby
# frozen_string_literal: true

require 'etc'

var = File.join(__dir__, 'var')
build = File.join(var, 'qemu', 'build')

exec({ 'LD_LIBRARY_PATH' => "#{__dir__}/var/fontconfig-build/src:#{ENV['LD_LIBRARY_PATH']}" }, *%W[
  #{build}/qemu-system-aarch64 -M virt -cpu host -accel kvm -m 2G
  -device ramfb -drive file=#{build}/pc-bios/edk2-aarch64-code.fd,format=raw,if=pflash,readonly=on -device qemu-xhci
  -device usb-kbd -device usb-tablet
  -drive file=#{var}/Windows11_InsiderPreview_Client_ARM64_en-us_22598.raw,format=raw,if=none,id=boot
  -device usb-storage,drive=boot,serial=boot
  -nic user,model=virtio-net-pci,mac=52:54:98:76:54:32
  -serial mon:stdio
], *ARGV)
exec({ 'LD_LIBRARY_PATH' => "#{__dir__}/var/fontconfig-build/src:#{ENV['LD_LIBRARY_PATH']}" }, *%W[
  #{build}/qemu-system-aarch64 -M virt
  -chardev stdio,id=c,mux=on -cpu cortex-a72 -device nec-usb-xhci
  -device usb-storage,drive=f -device VGA
  -drive file=#{var}/Windows11_InsiderPreview_Client_ARM64_en-us_22598.raw,format=raw,id=f,if=none
  -drive file=#{build}/pc-bios/edk2-aarch64-code.fd,format=raw,if=pflash,readonly=on
  -m 4G -mon c -serial chardev:c -smp #{Etc.nprocessors}
], *ARGV)
exec({ 'LD_LIBRARY_PATH' => "#{__dir__}/var/fontconfig-build/src:#{ENV['LD_LIBRARY_PATH']}" }, *%W[
  #{build}/qemu-system-aarch64 -M virt -cpu cortex-a72 -smp 3
  --accel tcg,thread=multi -m 2048 -pflash #{build}/pc-bios/edk2-aarch64-code.fd
  -device VGA -device nec-usb-xhci -device usb-kbd -device usb-mouse
  -device usb-storage,drive=boot
  -drive if=none,id=boot,file=#{var}/Windows11_InsiderPreview_Client_ARM64_en-us_22598.raw
], *ARGV)
