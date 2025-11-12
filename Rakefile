require 'dotenv/load' if ENV['RACK_ENV'] != 'production'

ENV['RACK_ENV'] ||= 'development'

# Set up Sinatra environment for ActiveRecord
require 'sinatra'
require 'sinatra/activerecord'

#  Configure database from YAML
set :database_file, 'config/database.yml'

# Load sinatra-activerecord rake tasks
require 'sinatra/activerecord/rake'

# Default task
task default: :spec

# RSpec task
begin
  require 'rspec/core/rake_task'
  RSpec::Core::RakeTask.new(:spec)
rescue LoadError
  # RSpec not available
end
