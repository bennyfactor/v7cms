ENV['RACK_ENV'] = 'test'

require 'rack/test'
require 'rspec'
require 'database_cleaner/active_record'
require 'webmock/rspec'

# Set up ActiveRecord before loading app
require 'sinatra/activerecord'
require 'yaml'
require 'omniauth'
require 'omniauth-google-oauth2'
require 'omniauth-github'

db_config = YAML.load_file('config/database.yml')['test']
ActiveRecord::Base.establish_connection(db_config)

# Configure OmniAuth for testing
OmniAuth.config.test_mode = true

# Configure WebMock to disable real HTTP requests except localhost
WebMock.disable_net_connect!(allow_localhost: true)

# Load the gem (which loads all models, helpers, services, and the application)
# This provides both V7CMS:: namespaced classes and backward-compatible aliases
require_relative '../app/cms'

RSpec.configure do |config|
  config.include Rack::Test::Methods

  # Define the app for Rack::Test
  def app
    CMS
  end

  # Database Cleaner configuration
  config.before(:suite) do
    DatabaseCleaner.strategy = :transaction
    DatabaseCleaner.clean_with(:truncation)
  end

  config.before(:each) do
    # Stub Gravatar requests by default (return 404 = no profile)
    # Tests that specifically test Gravatar functionality should override this
    stub_request(:get, /gravatar\.com/).to_return(status: 404)
  end

  config.around(:each) do |example|
    DatabaseCleaner.cleaning do
      # Clear Setting cache before each test to prevent test pollution
      Setting.clear_cache! if Setting.respond_to?(:clear_cache!)
      example.run
    end
  end

  # RSpec configuration
  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end

  config.shared_context_metadata_behavior = :apply_to_host_groups
  config.filter_run_when_matching :focus
  config.example_status_persistence_file_path = 'spec/examples.txt'
  config.disable_monkey_patching!
  config.warnings = true

  config.default_formatter = 'doc' if config.files_to_run.one?

  config.order = :random
  Kernel.srand config.seed
end
