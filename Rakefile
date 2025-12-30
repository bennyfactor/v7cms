require 'dotenv/load' if ENV['RACK_ENV'] != 'production'

ENV['RACK_ENV'] ||= 'development'

# Add lib to load path so 'require v7cms' works in rake tasks
$LOAD_PATH.unshift(File.expand_path('lib', __dir__))

# Set up Sinatra environment for ActiveRecord
require 'sinatra'
require 'sinatra/activerecord'

#  Configure database from YAML
set :database_file, 'config/database.yml'

# Load sinatra-activerecord rake tasks
require 'sinatra/activerecord/rake'

# Define environment task for loading the application
task :environment do
  require_relative 'app/cms'
end

# Load custom rake tasks
Dir.glob('lib/tasks/*.rake').each { |r| load r }

# Load v7cms gem rake tasks
load 'lib/v7cms/tasks/v7cms.rake'

# Default task
task default: :spec

# RSpec task
begin
  require 'rspec/core/rake_task'
  RSpec::Core::RakeTask.new(:spec)
rescue LoadError
  # RSpec not available
end
