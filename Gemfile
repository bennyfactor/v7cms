source 'https://rubygems.org'

ruby '>= 3.4'

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
gem 'json', '~> 2.19', '>= 2.19.2'

# API Documentation
gem 'swagger-blocks', '~> 3.0'

# XML generation for feeds
gem 'builder', '~> 3.2'
gem 'nokogiri', '~> 1.15'

# CSV export
gem 'csv', '~> 3.0'

# Email
gem 'mail', '~> 2.8'

# Image/Asset handling
gem 'fastimage', '~> 2.3'           # Fast image dimension detection (pure Ruby)
gem 'image_processing', '~> 1.12'   # Unified image processing API
gem 'mini_magick', '~> 4.12'        # ImageMagick wrapper (optional runtime dependency)

group :development, :test do
  gem 'pry', '~> 0.14'
  gem 'rspec', '~> 3.12'
  gem 'rack-test', '~> 2.1'
  gem 'database_cleaner-active_record', '~> 2.1'
  gem 'factory_bot', '~> 6.2'
  gem 'webmock', '~> 3.18'
end

group :development do
  gem 'rerun', '~> 0.14'
  gem 'puma', '~> 6.0'
  gem 'gem-release', '~> 2.2'

  # Linting and security analysis
  gem 'rubocop', '~> 1.76', require: false
  gem 'rubocop-performance', '~> 1.24', require: false
  gem 'rubocop-rspec', '~> 3.5', require: false
  gem 'brakeman', '~> 6.2', require: false
  gem 'bundler-audit', '~> 0.9', require: false
end
