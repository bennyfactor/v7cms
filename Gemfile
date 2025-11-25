source 'https://rubygems.org'

ruby '>= 3.0'

# Core framework
gem 'sinatra', '~> 3.0'
gem 'sinatra-activerecord', '~> 2.0'
gem 'sqlite3', '~> 2.1'
gem 'rake', '~> 13.0'

# Only needed for production FastCGI deployment (Linux only)
# Won't install in development/test (Docker) due to group exclusion
group :production do
  gem 'fcgi', '~> 0.9', install_if: -> { RbConfig::CONFIG['host_os'] =~ /linux/ }
end

# Authentication (OAuth)
gem 'omniauth', '~> 2.1'
gem 'omniauth-google-oauth2', '~> 1.1'
gem 'omniauth-github', '~> 2.0'
gem 'rack-protection', '~> 3.0'

# Rate limiting
gem 'rack-attack', '~> 6.7'

# Configuration
gem 'dotenv', '~> 2.8'

# JSON handling
gem 'json', '~> 2.6'

# XML generation for feeds
gem 'builder', '~> 3.2'
gem 'nokogiri', '~> 1.15'

group :development, :test do
  gem 'pry', '~> 0.14'
  gem 'rspec', '~> 3.12'
  gem 'rack-test', '~> 2.1'
  gem 'database_cleaner-active_record', '~> 2.1'
  gem 'factory_bot', '~> 6.2'
end

group :development do
  gem 'rerun', '~> 0.14'
  gem 'puma', '~> 6.0'
end
