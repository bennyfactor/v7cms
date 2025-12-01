# frozen_string_literal: true

require 'fileutils'

namespace :v7cms do
  desc 'Generate initial project files for a v7cms installation'
  task :setup do
    # Allow override via PROJECT_ROOT env var for testing
    project_root = ENV['PROJECT_ROOT'] || (defined?(V7CMS) ? V7CMS.project_root : Dir.pwd)

    puts "Setting up v7cms project in #{project_root}..."
    puts

    # Generate .env.example
    env_example = File.join(project_root, '.env.example')
    unless File.exist?(env_example)
      File.write(env_example, <<~ENV)
        # v7cms Configuration
        # Copy this file to .env and fill in your values

        # Required: Session secret (generate with: ruby -rsecurerandom -e 'puts SecureRandom.hex(32)')
        SESSION_SECRET=

        # OAuth Providers (at least one required for admin access)
        # Google OAuth: https://console.cloud.google.com/
        GOOGLE_CLIENT_ID=
        GOOGLE_CLIENT_SECRET=

        # GitHub OAuth: https://github.com/settings/developers
        GITHUB_CLIENT_ID=
        GITHUB_CLIENT_SECRET=

        # Required: Comma-separated list of admin email addresses
        ADMIN_EMAILS=your-email@example.com

        # Optional: reCAPTCHA v3 for comment spam prevention
        # https://www.google.com/recaptcha/admin
        RECAPTCHA_SITE_KEY=
        RECAPTCHA_SECRET_KEY=

        # Optional: Custom database path (default: db/ in project root)
        # DATABASE_PATH=/custom/path/to/db

        # Optional: Environment (development, test, production)
        # RACK_ENV=development
      ENV
      puts "  Created #{env_example}"
    else
      puts "  Skipped #{env_example} (already exists)"
    end

    # Generate config/database.yml.example
    config_dir = File.join(project_root, 'config')
    FileUtils.mkdir_p(config_dir)
    db_example = File.join(config_dir, 'database.yml.example')
    unless File.exist?(db_example)
      File.write(db_example, <<~YAML)
        # Database Configuration
        # Copy this file to database.yml to customize database settings
        # If not present, v7cms will use SQLite in the db/ directory

        development:
          adapter: sqlite3
          database: db/development.sqlite3
          pool: 5
          timeout: 5000

        test:
          adapter: sqlite3
          database: db/test.sqlite3
          pool: 5
          timeout: 5000

        production:
          adapter: sqlite3
          database: db/production.sqlite3
          pool: 5
          timeout: 5000

        # For PostgreSQL (requires 'pg' gem):
        # production:
        #   adapter: postgresql
        #   host: localhost
        #   database: v7cms_production
        #   username: your_username
        #   password: your_password
        #   pool: 5
      YAML
      puts "  Created #{db_example}"
    else
      puts "  Skipped #{db_example} (already exists)"
    end

    # Generate .gitignore
    gitignore = File.join(project_root, '.gitignore')
    unless File.exist?(gitignore)
      File.write(gitignore, <<~GITIGNORE)
        # Environment and secrets
        .env
        .env.local
        .env.*.local

        # Database files
        *.sqlite3
        *.sqlite3-shm
        *.sqlite3-wal
        db/*.sqlite3
        db/*.db

        # Configuration (may contain secrets)
        config/database.yml

        # Generated files
        public/css/output.css
        public/css/theme.css
        public/posts/*.html
        public/pages/*.html
        .htaccess

        # Ruby/Bundler
        .bundle/
        vendor/bundle/
        Gemfile.lock

        # Logs
        *.log
        log/

        # Temporary files
        tmp/
        *.tmp
        *.swp
        *~
        .byebug_history

        # OS files
        .DS_Store
        Thumbs.db

        # IDE/Editor files
        .idea/
        .vscode/
        *.sublime-project
        *.sublime-workspace
      GITIGNORE
      puts "  Created #{gitignore}"
    else
      puts "  Skipped #{gitignore} (already exists)"
    end

    # Create db directory
    db_dir = File.join(project_root, 'db')
    unless File.directory?(db_dir)
      FileUtils.mkdir_p(db_dir)
      puts "  Created #{db_dir}/"
    end

    # Create config.ru if it doesn't exist
    config_ru = File.join(project_root, 'config.ru')
    unless File.exist?(config_ru)
      File.write(config_ru, <<~RUBY)
        # frozen_string_literal: true

        require 'v7cms'

        run V7CMS::Application
      RUBY
      puts "  Created #{config_ru}"
    else
      puts "  Skipped #{config_ru} (already exists)"
    end

    # Create Rakefile if it doesn't exist
    rakefile = File.join(project_root, 'Rakefile')
    unless File.exist?(rakefile)
      File.write(rakefile, <<~RUBY)
        # frozen_string_literal: true

        require 'v7cms'

        # Load v7cms rake tasks
        require 'v7cms/tasks'

        # Load sinatra-activerecord rake tasks
        require 'sinatra/activerecord/rake'

        namespace :db do
          task :load_config do
            require 'v7cms'
          end
        end
      RUBY
      puts "  Created #{rakefile}"
    else
      puts "  Skipped #{rakefile} (already exists)"
    end

    puts
    puts 'Setup complete!'
    puts
    puts 'Next steps:'
    puts '  1. Copy .env.example to .env and configure your settings'
    puts '  2. Copy config/database.yml.example to config/database.yml (optional)'
    puts '  3. Run: bundle exec rake db:migrate'
    puts '  4. Run: bundle exec rackup'
    puts
  end

  desc 'Generate .htaccess file for Apache/FastCGI deployment'
  task :htaccess do
    require 'v7cms'

    project_root = V7CMS.project_root
    htaccess_path = File.join(project_root, '.htaccess')

    # Use the existing HtaccessGenerator if available
    if defined?(HtaccessGenerator)
      HtaccessGenerator.generate
      puts "Generated #{htaccess_path}"
    else
      puts 'Error: HtaccessGenerator not available'
      exit 1
    end
  end

  desc 'Regenerate all static HTML files (posts, pages)'
  task :regenerate do
    require 'v7cms'

    puts 'Regenerating static files...'

    if defined?(PostRenderer)
      Post.published.find_each do |post|
        PostRenderer.render_to_file(post)
        puts "  Rendered post: #{post.slug}"
      end
    end

    if defined?(PageRenderer)
      Page.published.find_each do |page|
        PageRenderer.render_to_file(page)
        puts "  Rendered page: #{page.slug}"
      end
    end

    puts 'Done!'
  end

  desc 'Show v7cms version'
  task :version do
    require_relative '../version'
    puts "v7cms #{V7CMS::VERSION}"
  end
end
