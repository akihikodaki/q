#!/usr/bin/env ruby
# frozen_string_literal: true

e_read, e_write = IO.pipe
r_read, r_write = IO.pipe
e_read.close_on_exec = false
r_write.close_on_exec = false
parent = Process.pid

fork do
  e_write.close
  r_read.close
  Process.setpgid 0, 0
  e_read.read 1

  exec 'slirp4netns', '-6e', e_read.fileno.to_s, '-r', r_write.fileno.to_s,
       parent.to_s, 'tap_host'
end

e_read.close
r_write.close
e_write.close_on_exec = false
r_read.close_on_exec = false

exec 'unshare', '--user', '--map-root-user', '--net', '--mount',
     File.join(__dir__, 'libexec/unshared'),
     e_write.fileno.to_s, r_read.fileno.to_s
