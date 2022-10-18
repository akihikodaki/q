#!/usr/bin/env ruby
# frozen_string_literal: true

require 'json'
require 'tmpdir'

Address = Struct.new(:local, :prefixlen)
Interface = Struct.new(:ifname, :inet, :inet6)
e = File.join(__dir__, 'e')
test = File.join(__dir__, 'libexec', 'test.sh')
results = File.join(__dir__, 'var', 'results', Time.now.to_s)
subject = Interface.new('enp0s2', nil, nil)
subjectvfs = %w[enp0s2v0 enp0s2v1].map { Interface.new(_1, nil, nil) }
helper = Interface.new('enp0s2', nil, nil)

begin
  system e, *%W[ssh fd00::ff:fe00:0 test -f /sys/devices/pci0000:00/0000:00:02.0/sriov_numvfs], exception: true
rescue RuntimeError
  subjectvfs = nil
end

unless subjectvfs.nil?
  File.open Dir.tmpdir, File::RDWR | File::TMPFILE do |file|
    file.write subjectvfs.size.to_s
    file.rewind
    system e, *%W[ssh fd00::ff:fe00:0 tee /sys/devices/pci0000:00/0000:00:02.0/sriov_numvfs], exception: true, in: file, out: :close
  end

  system e, *%W[ssh fd00::ff:fe00:0 sysctl net.ipv4.conf.all.accept_local=1], exception: true

  subjectvfs.each do |vf|
    begin
      system e, *%W[ssh fd00::ff:fe00:0 nmcli device connect #{vf.ifname}], exception: true
    rescue RuntimeError
      sleep 1
      retry
    end
  end
end

[
  ['fd00::ff:fe00:0', [subject, *subjectvfs]],
  ['fd00::ff:fe00:1', [helper]]
].each do
  host, interfaces = _1
  while interfaces.any? { |interface| interface.inet.nil? || interface.inet6.nil? }
    sleep 1
    stdout = IO.popen([e, 'ssh', host, *%W[ip -json address show]], &:read)
    JSON.parse(stdout).each do |address|
      interfaces.each do |interface|
        next if interface.ifname != address['ifname']

        address['addr_info'].each do |info|
          case info['family']
          when 'inet'
            interface.inet = Address.new(info['local'], info['prefixlen'].to_s)
          when 'inet6'
            if info['scope'] == 'global'
              interface.inet6 = Address.new(info['local'], info['prefixlen'].to_s)
            end
          end
        end
      end
    end
  end
end

if subjectvfs.nil?
  cases = [['subject-helper.txt', subject, helper]]
else
  cases = [
    ['subject-helper.txt', subject, helper],
    ['subject-subjectv0.txt', subject, subjectvfs[0]],
    ['subjectv0-helper.txt', subjectvfs[0], helper],
    ['subjectv0-subject.txt', subjectvfs[0], subject],
    ['subjectv0-subjectv1.txt', subjectvfs[0], subjectvfs[1]]
  ]
end

Dir.mkdir results
buffer = String.new

cases.each do
  path, local, remote = _1
  File.open File.join(results, path), File::CREAT | File::WRONLY do |file|
    command = [
      e, *%W[ssh fd00::ff:fe00:0 sh -s --],
      local.ifname, local.inet.local, local.inet.prefixlen,
      local.inet6.local, local.inet6.prefixlen,
      remote.ifname, remote.inet.local, remote.inet.prefixlen,
      remote.inet6.local, remote.inet6.prefixlen
    ]

    IO.popen command, in: test do |io|
      loop do
        begin
          io.readpartial IO::Buffer::PAGE_SIZE, buffer
        rescue EOFError
          break
        end

        STDOUT.write buffer
        file.write buffer
      end
    end
  end
end
