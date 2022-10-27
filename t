#!/usr/bin/env ruby
# frozen_string_literal: true

require 'json'
require 'tmpdir'

class Daemon
  D = File.join(__dir__, 'd')
  E = File.join(__dir__, 'e')

  attr_reader :pid_s

  def initialize(path)
    d_read, d_write = IO.pipe
    @pid = Kernel.spawn(D, d_write.fileno.to_s, pgroup: 0,
                        out: path, err: :out, d_write.fileno => d_write.fileno)
    begin
      @pid_s = @pid.to_s
      d_write.close
      d_read.read
      d_read.close
    rescue Exception
      kill
      raise
    end
  end

  def kill
    Process.kill 'TERM', @pid
    Process.wait
  end

  def popen(command, ...)
    IO.popen([E, '-t', @pid_s, *command], ...)
  end

  def spawn(...)
    super(E, '-t', @pid_s, ...)
  end

  def system(...)
    super(E, '-t', @pid_s, ...)
  end
end

class Host
  attr_reader :address, :interfaces

  X = File.join(__dir__, 'x')

  def initialize(daemon, path, interface_device, address, interfaces)
    @address = address
    @interfaces = interfaces
    interfaces.each { |interface| interface.host = self }
    @pid = spawn(X, '-l', path, '-t', daemon.pid_s, interface_device, '-snapshot',
                 pgroup: 0)
    begin
      begin
        daemon.system 'ssh', address, exception: true, in: :close
      rescue RuntimeError
        sleep 1
        retry
      end
    rescue Exception
      kill
      raise
    end
  end

  def kill
    Process.kill 'KILL', @pid
    Process.wait @pid
  end
end

Interface = Struct.new(:ifname, :host, :inet, :inet6)

cases = if ARGV[0] == 'igb'
          [
            ['subject-helper', true, 0, 'enp0s2', 'enp0s2'],
            ['subject-subjectv0', false, 1, 'enp0s2', 'enp0s2v0'],
            ['subjectv0-helper', true, 1, 'enp0s2v0', 'enp0s2'],
            ['subjectv0-subject', false, 1, 'enp0s2v0', 'enp0s2'],
            ['subjectv0-subjectv1', false, 2, 'enp0s2v0', 'enp0s2v1']
          ]
        else
          cases = [['subject-helper', true, 0, 'enp0s2', 'enp0s2']]
        end

results = File.join(__dir__, 'var', 'results', Time.now.to_s)
Dir.mkdir results

threads = cases.map do
  Thread.new(*_1) do |name, seperate_hosts, required_vfs, local_ifname, remote_ifname|
    local = Interface.new(local_ifname)
    remote = Interface.new(remote_ifname)
    hosts = []
    path = File.join(results, name)
    hosts_path = File.join(path, 'hosts')
    Dir.mkdir path
    daemon = Daemon.new(File.join(path, 'd.txt'))

    begin
      Dir.mkdir hosts_path

      if seperate_hosts
        hosts << Host.new(daemon, File.join(hosts_path, 'local.txt'),
                          ARGV[0], 'fd00::ff:fe00:0', [local])
        hosts << Host.new(daemon, File.join(hosts_path, 'remote.txt'),
                          'virtio-net', 'fd00::ff:fe00:1', [remote])
      else
        hosts << Host.new(daemon, File.join(hosts_path, 'local.txt'),
                          ARGV[0], 'fd00::ff:fe00:0',
                          [local, remote])
      end

      if required_vfs != 0
        File.open Dir.tmpdir, File::RDWR | File::TMPFILE do |file|
          file.write '0'
          file.rewind
          daemon.system *%w[ssh fd00::ff:fe00:0 tee /sys/devices/pci0000:00/0000:00:02.0/sriov_numvfs],
                        exception: true, in: file, out: :close
          file.rewind
          file.write required_vfs.to_s
          file.rewind
          daemon.system *%w[ssh fd00::ff:fe00:0 tee /sys/devices/pci0000:00/0000:00:02.0/sriov_numvfs],
                        exception: true, in: file, out: :close
        end
      end

      hosts.each do |host|
        %w[-4 -6].each do |version|
          [
            %w[del priority 0 table local],
            %w[add priority 1 table local]
          ].each do |command|
            daemon.system 'ssh', host.address, 'ip', version, 'rule', *command,
                          exception: true
          end
        end

        while host.interfaces.any? { |interface| interface.inet.nil? || interface.inet6.nil? }
          sleep 1
          stdout = daemon.popen(['ssh', host.address, *%W[ip -json address show]], &:read)
          JSON.parse(stdout).each do |address|
            host.interfaces.each do |interface|
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

        host.interfaces.each do |interface|
          [['-4', interface.inet], ['-6', interface.inet6]].each do |inet|
            version, address = inet
            daemon.system *%W[ssh #{host.address} ip #{version} rule add to #{address} iif lo priority 0 table main],
                          exception: true
          end
        end
      end

      [local, remote].permutation do |interfaces|
        [interfaces.map(&:inet), interfaces.map(&:inet6)].each do |inets|
          daemon.system 'ssh', interfaces[0].host.address, 'ip', 'route', 'add', inets[1], 'dev', interfaces[0].ifname, 'src', inets[0],
                        exception: true
        end
      end

      File.open File.join(path, 'result.txt'), File::CREAT | File::WRONLY do |file|
        command = [
          *%w[ssh fd00::ff:fe00:0 sh -s --],
          local.inet, local.inet6, remote.inet, remote.inet6
        ]
  
        daemon.popen command, in: File.join(__dir__, 'libexec', 'test.sh'), err: :out do |io|
          io.each do |line|
            puts "#{name}: #{line}"
            file.write line
          end
        end
      end
    ensure
      hosts.each(&:kill)
      daemon.kill
    end
  end
rescue
  threads.each { |thread| thread.kill if thread != Thread.current }
  raise
end

threads.each(&:join)
