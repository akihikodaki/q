#!/usr/bin/env ruby
# frozen_string_literal: true

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
    Process.wait @pid
  end

  def popen(command, ...)
    IO.popen([E, '-t', @pid_s, *command], ...)
  end

  def system(...)
    super(E, '-t', @pid_s, ...)
  end
end

class Host
  attr_reader :address

  X = File.join(__dir__, 'x')

  def initialize(daemon, path, interface_device, address)
    @address = address
    @pid = spawn(X, '-l', path, '-t', daemon.pid_s, interface_device, '-snapshot',
                 pgroup: 0)
    begin
      begin
        daemon.system 'ssh', '-o', 'ConnectTimeout=1', address, exception: true, in: :close
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

cases = if ARGV[0] == 'igb'
          [
            ['subject-helper', 0, 'enp0s4', 'enp0s3'],
            ['subject-subjectv0', 1, 'enp0s4', 'enp0s4v0'],
            ['subjectv0-helper', 1, 'enp0s4v0', 'enp0s3'],
            ['subjectv0-subject', 1, 'enp0s4v0', 'enp0s4'],
            ['subjectv0-subjectv1', 2, 'enp0s4v0', 'enp0s4v1']
          ]
        else
          cases = [['subject-helper', 0, 'enp0s4', 'enp0s3']]
        end

results = File.join(__dir__, 'var', 'results', Time.now.to_s)
Dir.mkdir results

daemon = Daemon.new(File.join(results, 'd.txt'))
begin
  cases.each do
    name, required_vfs, local, remote = _1
    path = File.join(results, name)
    Dir.mkdir path

    host = Host.new(daemon, File.join(path, 'x.txt'), ARGV[0], '10.0.2.15')
    begin
      File.open File.join(path, 'result.txt'), File::CREAT | File::WRONLY do |file|
        command = [
          'ssh', host.address, 'sh', '-s',
          '--', required_vfs.to_s, local, remote
        ]
  
        daemon.popen command, in: File.join(__dir__, 'libexec', 'test.sh'), err: :out do |io|
          io.each do |line|
            puts "#{name}: #{line}"
            file.write line
          end
        end
      end
    ensure
      host.kill
    end
  end

  path = File.join(results, 'dts')
  Dir.mkdir path

  host = Host.new(daemon, File.join(path, 'x.txt'), ARGV[0], '10.0.2.15')
  begin
    File.open File.join(path, 'result.txt'), File::CREAT | File::WRONLY do |file|
      command = [
        'ssh', host.address, '/home/person/dts/dts', '--config-file',
        'executions/execution_q.cfg'
      ]

      daemon.popen command, err: :out do |io|
        io.each do |line|
          puts "dts: #{line}"
          file.write line
        end
      end

      daemon.system 'scp', '-r', "#{host.address}:/home/person/dts/output", path
    end
  ensure
    host.kill
  end
ensure
  daemon.kill
end
