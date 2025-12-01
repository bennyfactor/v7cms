# frozen_string_literal: true

require 'sinatra/base'
require 'sinatra/activerecord'

module V7CMS
  # Main application class
  # Currently delegates to the existing CMS class during migration
  # Will eventually contain all application logic
  class Application < Sinatra::Base
    # Configure Sinatra settings
    configure do
      # Set the views directory - check user's project first, then gem
      views_paths = V7CMS.file_resolver.resolve_all('views')
      if views_paths.any?
        set :views, views_paths.first
      else
        # Fallback to app/views for backward compatibility during migration
        set :views, File.expand_path('../../app/views', V7CMS.gem_root)
      end

      # Set public folder - check user's project first, then gem
      public_path = V7CMS.file_resolver.resolve('public')
      if public_path
        set :public_folder, public_path
      else
        # Fallback to public/ for backward compatibility during migration
        set :public_folder, File.expand_path('../../public', V7CMS.gem_root)
      end

      set :static, true
    end

    # Database configuration
    def self.setup_database
      db_config_path = V7CMS.file_resolver.resolve('config/database.yml')
      db_config_path ||= File.join(V7CMS.gem_root, 'config', 'database.yml')

      if File.exist?(db_config_path)
        set :database_file, db_config_path
      end
    end
  end
end

# For backward compatibility during migration, require the existing CMS app
# This allows `run V7CMS::Application` to work while we migrate
# Eventually this require will be removed and all code will live in V7CMS::Application
require_relative '../../app/cms'

# Make CMS available as V7CMS::Application for gradual migration
module V7CMS
  # Alias the existing CMS class as the Application
  # This is temporary - once migration is complete, Application will be the real class
  remove_const(:Application) if const_defined?(:Application)
  Application = ::CMS
end
