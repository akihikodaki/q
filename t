#!/usr/bin/env ruby
# frozen_string_literal: true

require 'shellwords'

Dir.chdir __dir__

class Host
  attr_reader :address

  def initialize(path, interface_device)
    @pid = spawn('./x', interface_device,
                 in: :close, out: path, err: [:child, :out], pgroup: 0)
    begin
      begin
        system 'mkosi', 'ssh', exception: true, in: :close
      rescue RuntimeError
        sleep 1
        retry
      end
    rescue Exception
      wait
      raise
    end
  end

  def poweroff
    system 'mkosi', 'ssh', 'poweroff', in: :close
    wait
  end

  def ssh(command, ...)
    IO.popen(['mkosi', 'ssh', command], ...)
  end

  def wait
    Process.wait @pid
  end
end

cases = if ARGV[0] == 'igb'
          [
            ['subject-helper', 0, 'ens2', 'ens1f0'],
            ['subject-subjectv0', 1, 'ens2', 'ens2v0'],
            ['subjectv0-helper', 1, 'ens2v0', 'ens1f0'],
            ['subjectv0-subject', 1, 'ens2v0', 'ens2'],
            ['subjectv0-subjectv1', 2, 'ens2v0', 'ens2v1']
          ]
        else
          cases = [['subject-helper', 0, 'ens2', 'ens1f0']]
        end

results = File.join('var', 'results', Time.now.to_s)
Dir.mkdir results

cases.each do
  name, required_vfs, local, remote = _1
  path = File.join(results, name)
  Dir.mkdir path

  host = Host.new(File.join(path, 'x.txt'), ARGV[0])
  begin
    File.open File.join(path, 'result.txt'), File::CREAT | File::WRONLY do |file|
      command = [
        'exec', 'sh', '-s', '--', required_vfs.to_s, local, remote
      ].shelljoin

      host.ssh command, in: 'test.sh', err: [:child, :out] do |io|
        io.each do |line|
          puts "#{name}: #{line}"
          file.write line
        end
      end
    end
  ensure
    host.poweroff
  end
end

path = File.join(results, 'dts')
Dir.mkdir path

host = Host.new(File.join(path, 'x.txt'), ARGV[0])
begin
  File.open File.join(path, 'result.txt'), File::CREAT | File::WRONLY do |file|
    command = "cd /mnt/dts && ./main.py --config-file executions/execution_q.cfg --output ../#{path.shellescape}/output"

    host.ssh command, err: [:child, :out] do |io|
      io.each do |line|
        puts "dts: #{line}"
        file.write line
      end
    end
  end
ensure
  host.poweroff
end
