ENV['RACK_ENV'] = 'test'

require 'rack/test'
require 'rspec'
require 'database_cleaner/active_record'

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

# Load models
require_relative '../app/models/user'
require_relative '../app/models/post'
require_relative '../app/models/theme'

# Load Sinatra app for integration tests
# For model-only tests, set SKIP_APP_LOAD=true
unless ENV['SKIP_APP_LOAD']
  # Load full app for route tests
  require_relative '../app/cms'
end

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
