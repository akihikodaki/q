#!/usr/bin/env ruby
# frozen_string_literal: true

require File.join(__dir__, 'lib')

q = Q.new
q.enter(*q.argv)
