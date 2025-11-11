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
rescue LoadError
  # Bundler not available; we'll fall back to system gems.
  # This is intentional: it lets the script still run if Bundler isn't installed,
  # but you'll need `fcgi` in the system gems in that case.
  warn "[startup] Bundler not available; using system gem paths only."
end

# Now load fcgi from either the bundle or system gems
begin
  require 'fcgi'
rescue LoadError => e
  warn "[startup] Could not load 'fcgi' gem: #{e.class}: #{e.message}"
  warn "[startup] Ensure you have `gem 'fcgi'` in your Gemfile and ran `bundle install`"
  exit 1
end

HTML_BODY = <<~HTML
  <html>
    <head>
      <title>Hello World!</title>
    </head>
    <body>
      <h1>Hello world!</h1>
    </body>
  </html>
HTML

def handle_request(cgi)
  headers = {
    # `type` is what Ruby's CGI/FCGI expects for Content-Type
    "type"           => "text/html",
    "status"         => "200 OK",
    "Connection"     => "close",
    "Content-Length" => HTML_BODY.bytesize.to_s
  }

  cgi.out(headers) { HTML_BODY }
end

begin
  FCGI.each_cgi do |cgi|
    begin
      handle_request(cgi)
    rescue StandardError => e
      warn "[#{Time.now.utc}] FastCGI request failed: #{e.class}: #{e.message}"
      warn e.backtrace.join("\n")

      # Best-effort error response
      begin
        cgi.out("type" => "text/plain", "status" => "500 Internal Server Error") do
          "Internal Server Error\n"
        end
      rescue StandardError
        # If even this fails, just give up on this request
      end
    end
  end
rescue Interrupt
  warn "[shutdown] FastCGI loop interrupted, exiting."
rescue StandardError => e
  warn "[fatal] FastCGI loop crashed: #{e.class}: #{e.message}"
  warn e.backtrace.join("\n")
  exit 1
end

