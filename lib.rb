# frozen_string_literal: true

require 'optparse'
require 'socket'

class Q
  attr_reader :argv, :libexec, :var

  def initialize(&block)
    parser = OptionParser.new(&block)

    parser.on('-t', '--target [TARGET]', String, 'target process to get namespaces from') do
      @target = _1
    end

    @argv = parser.order(ARGV)
    @libexec = File.join(__dir__, 'libexec')
    @var = File.join(__dir__, 'var')
    @sock = File.join(@var, 'sock')

    if @target.nil?
      @target = Dir.each_child(@sock).first
      raise 'No d running' if @target.nil?
    end
  end

  def open
    UNIXSocket.new File.join(@sock, @target)
  end

  def enter(*argv)
    ENV['Q'] = __dir__
    
    exec(*%W[nsenter -m -n -U --preserve-credentials -w#{Dir.pwd} -t], @target,
         *argv)
  end
end
