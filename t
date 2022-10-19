#!/usr/bin/env ruby
# frozen_string_literal: true

require 'json'
require 'tmpdir'

Interface = Struct.new(:ifname, :host, :inet, :inet6)
e = File.join(__dir__, 'e')
test = File.join(__dir__, 'libexec', 'test.sh')
results = File.join(__dir__, 'var', 'results', Time.now.to_s)
subject = Interface.new('enp0s2')
subjectvfs = %w[enp0s2v0 enp0s2v1].map { Interface.new(_1) }
helper = Interface.new('enp0s2')

begin
  system e, *%w[ssh fd00::ff:fe00:0 test -f /sys/devices/pci0000:00/0000:00:02.0/sriov_numvfs], exception: true
rescue RuntimeError
  subjectvfs = nil
end

unless subjectvfs.nil?
  File.open Dir.tmpdir, File::RDWR | File::TMPFILE do |file|
    file.write '0'
    file.rewind
    system e, *%w[ssh fd00::ff:fe00:0 tee /sys/devices/pci0000:00/0000:00:02.0/sriov_numvfs], exception: true, in: file, out: :close
    file.rewind
    file.write subjectvfs.size.to_s
    file.rewind
    system e, *%w[ssh fd00::ff:fe00:0 tee /sys/devices/pci0000:00/0000:00:02.0/sriov_numvfs], exception: true, in: file, out: :close
  end

  %w[-4 -6].each do
    begin
      system e, *%W[ssh fd00::ff:fe00:0 ip #{_1} rule del priority 0 table local], exception: true
    rescue RuntimeError
    end

    begin
      system e, *%W[ssh fd00::ff:fe00:0 ip #{_1} rule add priority 1 table local], exception: true
    rescue RuntimeError
    end
  end
end

[
  ['fd00::ff:fe00:0', [subject, *subjectvfs]],
  ['fd00::ff:fe00:1', [helper]]
].each do
  host, interfaces = _1
  interfaces.each { |interface| interface.host = host }
  while interfaces.any? { |interface| interface.inet.nil? || interface.inet6.nil? }
    sleep 1
    stdout = IO.popen([e, 'ssh', host, *%W[ip -json address show]], &:read)
    JSON.parse(stdout).each do |address|
      interfaces.each do |interface|
        next if interface.ifname != address['ifname']

        address['addr_info'].each do |info|
          case info['family']
          when 'inet'
            interface.inet = info['local']
          when 'inet6'
            interface.inet6 = info['local'] if info['scope'] == 'global'
          end
        end
      end
    end
  end
end

[subject, *subjectvfs].each do |interface|
  [['-4', interface.inet], ['-6', interface.inet6]].each do |inet|
    version, address = inet
    system e, *%W[ssh fd00::ff:fe00:0 ip #{version} rule add to #{address} iif lo priority 0 table main], exception: true
  end
rescue RuntimeError
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

  [local, remote].permutation do |interfaces|
    [interfaces.map(&:inet), interfaces.map(&:inet6)].each do |inets|
      begin
        system e, 'ssh', interfaces[0].host, 'ip', 'route', 'del', inets[1], exception: true
      rescue RuntimeError
      end

      system e, 'ssh', interfaces[0].host, 'ip', 'route', 'add', inets[1], 'dev', interfaces[0].ifname, 'src', inets[0], exception: true
    end
  end

  File.open File.join(results, path), File::CREAT | File::WRONLY do |file|
    command = [
      e, *%w[ssh fd00::ff:fe00:0 sh -s --],
      local.ifname, local.inet, local.inet6,
      remote.ifname, remote.inet, remote.inet6
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
