# frozen_string_literal: true

require_relative 'lib/v7cms/version'

Gem::Specification.new do |spec|
  spec.name          = 'v7cms'
  spec.version       = V7CMS::VERSION
  spec.authors       = ['Ben Factor']
  spec.email         = ['ben@bennyfactor.com']

  spec.summary       = 'A minimal content management system built with Ruby and Sinatra'
  spec.description   = <<~DESC
    v7cms is a lightweight content management system featuring OAuth authentication,
    a RESTful API, an Alpine.js admin interface, and support for custom themes.
    Designed for simplicity and easy deployment on shared hosting or containers.
  DESC
  spec.homepage      = 'https://github.com/bennyfactor/v7cms'
  spec.license       = 'MIT'

  spec.required_ruby_version = '>= 3.4'

  # Files to include in the gem
  spec.files = Dir[
    'lib/**/*',
    'app/**/*',
    'config/**/*',
    'db/migrate/**/*',
    'public/**/*',
    'LICENSE',
    'README.md'
  ].reject { |f| f.include?('sqlite3') || f.end_with?('.log') }

  spec.require_paths = ['lib']


  # Core framework dependencies
  spec.add_dependency 'sinatra', '~> 3.0'
  spec.add_dependency 'sinatra-activerecord', '~> 2.0'
  spec.add_dependency 'sqlite3', '~> 2.1'
  spec.add_dependency 'rake', '~> 13.0'

  # Authentication
  spec.add_dependency 'omniauth', '~> 2.1'
  spec.add_dependency 'omniauth-google-oauth2', '~> 1.1'
  spec.add_dependency 'omniauth-github', '~> 2.0'
  spec.add_dependency 'rack-protection', '~> 3.0'

  # Rate limiting
  spec.add_dependency 'rack-attack', '~> 6.7'

  # Configuration
  spec.add_dependency 'dotenv', '~> 2.8'

  # JSON handling
  spec.add_dependency 'json', '~> 2.19', '>= 2.19.2'

  # API Documentation
  spec.add_dependency 'swagger-blocks', '~> 3.0'

  # XML generation for feeds
  spec.add_dependency 'builder', '~> 3.2'
  spec.add_dependency 'nokogiri', '~> 1.15'

  # Image/Asset handling
  spec.add_dependency 'fastimage', '~> 2.3'
  spec.add_dependency 'image_processing', '~> 1.12'
  spec.add_dependency 'mini_magick', '~> 4.12'

  # Ruby 3.5 stdlib extractions
  spec.add_dependency 'csv', '~> 3.0'
  spec.add_dependency 'ostruct', '~> 0.6'

  # CSS compilation
  spec.add_dependency 'tailwindcss-ruby', '~> 4.2'

  # Email
  spec.add_dependency 'mail', '~> 2.8'

  # Development dependencies
  spec.add_development_dependency 'database_cleaner-active_record', '~> 2.1'
  spec.add_development_dependency 'factory_bot', '~> 6.2'
  spec.add_development_dependency 'pry', '~> 0.14'
  spec.add_development_dependency 'puma', '~> 6.0'
  spec.add_development_dependency 'rack-test', '~> 2.1'
  spec.add_development_dependency 'rerun', '~> 0.14'
  spec.add_development_dependency 'rspec', '~> 3.12'
  spec.add_development_dependency 'webmock', '~> 3.18'

  # Metadata
  spec.metadata['homepage_uri'] = spec.homepage
  spec.metadata['source_code_uri'] = spec.homepage
  spec.metadata['changelog_uri'] = "#{spec.homepage}/blob/main/CHANGELOG.md"
  spec.metadata['rubygems_mfa_required'] = 'true'
end
