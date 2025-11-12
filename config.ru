# Load environment variables in development
require 'dotenv/load' if ENV['RACK_ENV'] != 'production'

# Set up database connection for Sinatra
ENV['RACK_ENV'] ||= 'development'

# Require the main application
require_relative 'app/cms'

# Run the application
run CMS
