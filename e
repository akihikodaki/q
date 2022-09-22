#!/usr/bin/env ruby
# frozen_string_literal: true

exec(*%W[
  nsenter -t #{File.read(File.join(__dir__, 'var', 'pid'))}
  -m -n -U --preserve-credentials -w
], *ARGV)
