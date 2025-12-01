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
      # Set the views directory
      # Priority: 1. User's project (views/), 2. Gem views (lib/v7cms/views/), 3. Fallback (app/views for backward compatibility)
      views_paths = V7CMS.file_resolver.resolve_all('views')
      if views_paths.any?
        set :views, views_paths.first
      else
        # Fallback to app/views for backward compatibility during migration
        # This allows the current standalone app to continue working
        fallback_views = File.expand_path('../../app/views', V7CMS.gem_root)
        set :views, fallback_views
      end

      # Set public folder
      # Priority: 1. User's project (public/), 2. Gem public (lib/v7cms/public/), 3. Fallback (public/ for backward compatibility)
      public_path = V7CMS.file_resolver.resolve('public')
      if public_path
        set :public_folder, public_path
      else
        # Fallback to public/ for backward compatibility during migration
        # This allows the current standalone app to continue working
        fallback_public = File.expand_path('../../public', V7CMS.gem_root)
        set :public_folder, fallback_public
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
