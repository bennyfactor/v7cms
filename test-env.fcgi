#!/usr/bin/env ruby
# Test script to check environment variables

puts "Content-Type: text/plain\r\n\r\n"
puts "PATH from environment:"
puts ENV['PATH']
puts "\n"
puts "CUSTOM_TEST_VAR from environment:"
puts ENV['CUSTOM_TEST_VAR'] || '(not set)'
puts "\n"
puts "which ruby:"
puts `which ruby 2>&1`
puts "\n"
puts "Ruby version:"
puts RUBY_VERSION
puts "\n"
puts "Ruby path:"
puts RbConfig.ruby
