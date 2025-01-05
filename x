#!/usr/bin/env ruby
# frozen_string_literal: true

require 'etc'

exec({
       'ASAN_OPTIONS' => 'abort_on_error=1',
       'LD_LIBRARY_PATH' => "#{__dir__}/var/fontconfig-build/src:#{ENV['LD_LIBRARY_PATH']}"
     }, 'mkosi', "--qemu-smp=#{Etc.nprocessors}",
     'qemu', '-device', 'pcie-root-port,id=port1,slot=1', *ARGV)
