# frozen_string_literal: true

require 'fileutils'

namespace :v7cms do
  desc 'Generate initial project files for a v7cms installation'
  task :setup do
    # Allow override via PROJECT_ROOT env var for testing
    # Check if V7CMS is fully loaded (has project_root method) or just partially defined
    project_root = ENV['PROJECT_ROOT'] || (defined?(V7CMS) && V7CMS.respond_to?(:project_root) ? V7CMS.project_root : Dir.pwd)

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

    # Create or update Rakefile
    # Overwrite if it exists but is missing sinatra-activerecord (minimal bootstrap Rakefile)
    rakefile = File.join(project_root, 'Rakefile')
    rakefile_content = <<~RUBY
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

    if File.exist?(rakefile)
      existing_content = File.read(rakefile)
      if existing_content.include?('sinatra/activerecord/rake')
        puts "  Skipped #{rakefile} (already complete)"
      else
        File.write(rakefile, rakefile_content)
        puts "  Updated #{rakefile} (added database tasks)"
      end
    else
      File.write(rakefile, rakefile_content)
      puts "  Created #{rakefile}"
    end

    # __dir__ is lib/v7cms/tasks, so go up to lib/v7cms for templates
    templates_dir = File.expand_path('../templates', __dir__)

    # Copy setup.php for production FastCGI deployment
    setup_php = File.join(project_root, 'setup.php')
    unless File.exist?(setup_php)
      source_setup_php = File.join(templates_dir, 'setup.php')

      if File.exist?(source_setup_php)
        FileUtils.cp(source_setup_php, setup_php)
        puts "  Created #{setup_php}"
      else
        puts "  Warning: setup.php template not found in gem"
      end
    else
      puts "  Skipped #{setup_php} (already exists)"
    end

    # Copy index.fcgi for production FastCGI deployment
    index_fcgi = File.join(project_root, 'index.fcgi')
    unless File.exist?(index_fcgi)
      source_index_fcgi = File.join(templates_dir, 'index.fcgi')

      if File.exist?(source_index_fcgi)
        FileUtils.cp(source_index_fcgi, index_fcgi)
        FileUtils.chmod(0o755, index_fcgi)
        puts "  Created #{index_fcgi}"
      else
        puts "  Warning: index.fcgi template not found in gem"
      end
    else
      puts "  Skipped #{index_fcgi} (already exists)"
    end

    # Add fcgi gem to Gemfile for FastCGI deployment (Linux only)
    gemfile_path = File.join(project_root, 'Gemfile')
    if File.exist?(gemfile_path)
      gemfile_content = File.read(gemfile_path)
      unless gemfile_content.include?('fcgi')
        fcgi_line = "\n# FastCGI support for production (only installed on Linux)\ninstall_if -> { RUBY_PLATFORM =~ /linux/ } do\n  gem 'fcgi'\nend\n"
        File.write(gemfile_path, gemfile_content + fcgi_line)
        puts "  Updated #{gemfile_path} (added fcgi gem for FastCGI)"
      else
        puts "  Skipped #{gemfile_path} (fcgi already present)"
      end
    end

    puts
    puts 'Setup complete!'
    puts
    puts 'Next steps:'
    puts '  1. Copy .env.example to .env and configure your settings'
    puts '  2. Copy config/database.yml.example to config/database.yml (optional)'
    puts '  3. Run: bundle exec rake v7cms:install_migrations'
    puts '  4. Run: bundle exec rake db:migrate'
    puts '  5. Run: bundle exec rackup'
    puts
    puts 'For production FastCGI deployment:'
    puts '  - Visit setup.php in your browser to auto-configure Ruby paths'
    puts '  - Or manually update the shebang in index.fcgi'
    puts
  end

  desc 'Generate .htaccess file for Apache/FastCGI deployment'
  task :htaccess do
    require 'v7cms'

    project_root = V7CMS.project_root
    htaccess_path = File.join(project_root, '.htaccess')

    # Use the namespaced HtaccessGenerator
    if defined?(V7CMS::HtaccessGenerator)
      V7CMS::HtaccessGenerator.generate
      puts "Generated #{htaccess_path}"
    else
      puts 'Error: V7CMS::HtaccessGenerator not available'
      exit 1
    end
  end

  desc 'Regenerate all static HTML files (posts, pages)'
  task :regenerate do
    require 'v7cms'

    puts 'Regenerating static files...'

    if defined?(V7CMS::PostRenderer) && defined?(V7CMS::Post)
      V7CMS::Post.published.find_each do |post|
        V7CMS::PostRenderer.render_to_static(post)
        puts "  Rendered post: #{post.slug}"
      end
    end

    if defined?(V7CMS::PageRenderer) && defined?(V7CMS::Page)
      V7CMS::Page.published.find_each do |page|
        V7CMS::PageRenderer.render_to_static(page)
        puts "  Rendered page: #{page.slug}"
      end
    end

    puts 'Done!'
  end

  desc 'Copy migrations from gem to project (use FORCE=true to overwrite changed migrations)'
  task :install_migrations do
    require 'v7cms'
    require 'digest'

    gem_migrations = File.join(V7CMS.gem_root, 'db', 'migrate')
    project_migrations = File.join(V7CMS.project_root, 'db', 'migrate')
    force = ENV['FORCE'] == 'true'

    unless File.directory?(gem_migrations)
      puts "Error: No migrations found in gem at #{gem_migrations}"
      exit 1
    end

    FileUtils.mkdir_p(project_migrations)

    copied = 0
    updated = 0
    skipped = 0

    Dir.glob(File.join(gem_migrations, '*.rb')).each do |migration|
      filename = File.basename(migration)
      target = File.join(project_migrations, filename)

      if File.exist?(target)
        # Compare file contents using MD5 hash
        gem_hash = Digest::MD5.file(migration).hexdigest
        project_hash = Digest::MD5.file(target).hexdigest

        if gem_hash == project_hash
          skipped += 1
        elsif force
          FileUtils.cp(migration, target)
          updated += 1
          puts "  Updated: #{filename}"
        else
          puts "  Changed: #{filename} (use FORCE=true to update)"
          skipped += 1
        end
      else
        FileUtils.cp(migration, target)
        copied += 1
        puts "  Copied: #{filename}"
      end
    end

    puts
    puts "Migrations: #{copied} copied, #{updated} updated, #{skipped} unchanged"
    if updated > 0 || copied > 0
      puts "Run 'bundle exec rake db:migrate' to apply migrations"
    end
  end

  desc 'Show v7cms version'
  task :version do
    require_relative '../version'
    puts "v7cms #{V7CMS::VERSION}"
  end
end
