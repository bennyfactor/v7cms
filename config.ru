# Load environment variables in development
require 'dotenv/load' if ENV['RACK_ENV'] != 'production'

# Set up database connection for Sinatra
# Default to production if RACK_ENV not set (safer for deployments)
ENV['RACK_ENV'] ||= 'production'

# Require the main application
require_relative 'app/cms'

# Run the application
run CMS
