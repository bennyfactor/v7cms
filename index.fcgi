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

# Now load fcgi from either the bundle or system gems
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
  rack_app, options = Rack::Builder.parse_file('config.ru')
rescue LoadError => e
  warn "[startup] Could not load Rack: #{e.class}: #{e.message}"
  exit 1
rescue StandardError => e
  warn "[startup] Failed to load config.ru: #{e.class}: #{e.message}"
  warn e.backtrace.join("\n")
  exit 1
end

def handle_request(cgi, app)
  # Build Rack environment from FastCGI CGI object
  env = {
    'REQUEST_METHOD'    => cgi.env_table['REQUEST_METHOD'] || 'GET',
    'SCRIPT_NAME'       => '',
    'PATH_INFO'         => cgi.env_table['PATH_INFO'] || '/',
    'QUERY_STRING'      => cgi.env_table['QUERY_STRING'] || '',
    'SERVER_NAME'       => cgi.env_table['SERVER_NAME'] || 'localhost',
    'SERVER_PORT'       => cgi.env_table['SERVER_PORT'] || '80',
    'SERVER_PROTOCOL'   => cgi.env_table['SERVER_PROTOCOL'] || 'HTTP/1.1',
    'rack.version'      => Rack::VERSION,
    'rack.url_scheme'   => (cgi.env_table['HTTPS'] == 'on' ? 'https' : 'http'),
    'rack.input'        => cgi.in,
    'rack.errors'       => $stderr,
    'rack.multithread'  => false,
    'rack.multiprocess' => true,
    'rack.run_once'     => false
  }

  # Copy HTTP headers
  cgi.env_table.each do |key, value|
    next if key =~ /^(REQUEST_METHOD|SCRIPT_NAME|PATH_INFO|QUERY_STRING|SERVER_NAME|SERVER_PORT|SERVER_PROTOCOL)$/
    if key =~ /^HTTP_(.+)$/
      env[$1.upcase.gsub('-', '_')] = value
    else
      env[key] = value
    end
  end

  # Call the Rack application
  status, headers, body = app.call(env)

  # Convert status to string format
  status_text = Rack::Utils::HTTP_STATUS_CODES[status] || 'Unknown'

  # Build FastCGI headers
  fcgi_headers = {
    'status' => "#{status} #{status_text}"
  }

  headers.each do |key, value|
    fcgi_headers[key] = value
  end

  # Send response
  cgi.out(fcgi_headers) do
    output = []
    body.each { |chunk| output << chunk }
    body.close if body.respond_to?(:close)
    output.join
  end
rescue StandardError => e
  warn "[#{Time.now.utc}] FastCGI request failed: #{e.class}: #{e.message}"
  warn e.backtrace.join("\n")

  # Best-effort error response
  begin
    cgi.out('type' => 'text/html', 'status' => '500 Internal Server Error') do
      <<~HTML
        <html>
          <head><title>500 Internal Server Error</title></head>
          <body>
            <h1>Internal Server Error</h1>
            <p>The application encountered an error.</p>
          </body>
        </html>
      HTML
    end
  rescue StandardError
    # If even this fails, just give up on this request
  end
end

begin
  FCGI.each_cgi do |cgi|
    handle_request(cgi, rack_app)
  end
rescue Interrupt
  warn "[shutdown] FastCGI loop interrupted, exiting."
rescue StandardError => e
  warn "[fatal] FastCGI loop crashed: #{e.class}: #{e.message}"
  warn e.backtrace.join("\n")
  exit 1
end
