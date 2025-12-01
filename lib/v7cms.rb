# frozen_string_literal: true

# Load dotenv in non-production environments
require 'dotenv/load' if ENV['RACK_ENV'] != 'production'

# Set default environment
ENV['RACK_ENV'] ||= 'development'

require_relative 'v7cms/version'
require_relative 'v7cms/file_resolver'

module V7CMS
  class << self
    attr_writer :project_root, :gem_root

    # Project root - where the consuming application lives
    # Defaults to current working directory
    def project_root
      @project_root ||= Dir.pwd
    end

    # Gem root - where the v7cms gem is installed
    def gem_root
      @gem_root ||= File.expand_path('..', __dir__)
    end

    # File resolver instance for path lookups
    def file_resolver
      @file_resolver ||= FileResolver.new(
        project_root: project_root,
        gem_root: gem_root
      )
    end

    # Reset file resolver (useful for testing)
    def reset_file_resolver!
      @file_resolver = nil
    end

    # Configure the gem
    def configure
      yield self if block_given?
      reset_file_resolver! # Rebuild resolver with new settings
    end

    # Database directory - configurable via DATABASE_PATH env var
    def database_path
      ENV['DATABASE_PATH'] || File.join(project_root, 'db')
    end
  end
end

# Require the application after V7CMS module is defined
require_relative 'v7cms/application'
