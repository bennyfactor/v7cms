#!/usr/bin/env ruby
# frozen_string_literal: true

# Ensure we run with the script's directory as the working directory
APP_ROOT = File.expand_path(__dir__)
begin
  Dir.chdir(APP_ROOT)
rescue SystemCallError => e
  warn "[startup] Failed to chdir to #{APP_ROOT}: #{e.class}: #{e.message}"
end

# Try to activate Bundler (so the Gemfile is honored even without `bundle exec`)
begin
  require 'bundler/setup'
  Bundler.require(:default, :production)
rescue LoadError
  # Bundler not available; we'll fall back to system gems.
  warn "[startup] Bundler not available; using system gem paths only."
end

# Load environment variables from .env if dotenv is available
begin
  require 'dotenv'
  Dotenv.load
rescue LoadError
  warn "[startup] dotenv not available; skipping .env file"
end

# Set production environment by default for FastCGI
ENV['RACK_ENV'] ||= 'production'

# Load FCGI gem first
begin
  require 'fcgi'
rescue LoadError => e
  warn "[startup] Could not load 'fcgi' gem: #{e.class}: #{e.message}"
  warn "[startup] Ensure you have `gem 'fcgi'` in your Gemfile and ran `bundle install`"
  exit 1
end

# Load the Rack application from config.ru
begin
  require 'rack'
  require 'rack/handler/fastcgi'

  rack_app, options = Rack::Builder.parse_file('config.ru')
rescue LoadError => e
  warn "[startup] Could not load Rack: #{e.class}: #{e.message}"
  exit 1
rescue StandardError => e
  warn "[startup] Failed to load config.ru: #{e.class}: #{e.message}"
  warn e.backtrace.join("\n")
  exit 1
end

# Use Rack's built-in FastCGI handler
begin
  Rack::Handler::FastCGI.run(rack_app)
rescue Interrupt
  warn "[shutdown] FastCGI handler interrupted, exiting."
rescue StandardError => e
  warn "[fatal] FastCGI handler crashed: #{e.class}: #{e.message}"
  warn e.backtrace.join("\n")
  exit 1
end
