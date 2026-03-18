# frozen_string_literal: true

require 'sinatra/base'
require 'sinatra/activerecord'
require 'json'
require 'securerandom'
require 'omniauth'
require 'omniauth-google-oauth2'
require 'omniauth-github'

module V7CMS
  # Main Sinatra application class
  # Contains all routes, configuration, and helpers for the v7cms application
  class Application < Sinatra::Base
    # Register Sinatra::ActiveRecord if available (not in test model-only context)
    register Sinatra::ActiveRecord if defined?(Sinatra::ActiveRecord)

    # Database configuration - load from YAML
    # Priority: 1. Project config/database.yml, 2. Gem config/database.yml
    configure do
      db_config_path = V7CMS.file_resolver.resolve('config/database.yml')
      db_config_path ||= File.join(V7CMS.gem_root, 'config', 'database.yml')

      if File.exist?(db_config_path)
        set :database_file, db_config_path
      end
    end

    # Include helpers
    helpers V7CMS::AuthHelper
    helpers V7CMS::CdnHelper
    helpers V7CMS::MenuHelper

    # Enable sessions for authentication
    enable :sessions
    set :session_secret, ENV.fetch('SESSION_SECRET', SecureRandom.hex(32))
    # Use simple session config - SameSite/Secure might be breaking session persistence
    set :sessions, true unless ENV['RACK_ENV'] == 'test'

    # Serve static files from public directory
    # Priority: 1. User's project (public/), 2. Gem public (lib/v7cms/public/), 3. Fallback (public/ for backward compatibility)
    configure do
      public_path = V7CMS.file_resolver.resolve('public')
      if public_path
        set :public_folder, public_path
      else
        # Fallback to public/ for backward compatibility during migration
        fallback_public = File.join(V7CMS.gem_root, 'public')
        set :public_folder, fallback_public
      end
      set :static, true
    end

    # Set views directories (supports multiple paths for user overrides)
    # Priority: 1. User's project (views/), 2. Gem views (lib/v7cms/views/)
    # User can add custom layouts in their views/ folder without copying all gem views
    configure do
      views_paths = V7CMS.file_resolver.resolve_all('views')
      if views_paths.empty?
        # Fallback to app/views for backward compatibility during migration
        views_paths = [File.join(V7CMS.gem_root, 'app', 'views')]
      end
      # Store all paths for multi-path template lookup
      set :views_paths, views_paths
      # Set primary views path (required by Sinatra for default behavior)
      set :views, views_paths.first
    end

    # Override find_template to search multiple view paths
    # This allows users to add custom layouts without copying all gem views
    def find_template(views, name, engine)
      # Get all configured view paths
      all_views = settings.views_paths || [views]

      all_views.each do |view_path|
        super(view_path, name, engine) do |file|
          return yield(file) if File.exist?(file)
        end
      end

      # If not found in any path, yield the default path for error handling
      yield ::File.join(views, "#{name}.erb")
    end

    # CSRF protection (disabled in test)
    # Disable AuthenticityToken entirely - using session-based auth instead
    use Rack::Protection, except: [:session_hijacking, :remote_token, :authenticity_token] unless ENV['RACK_ENV'] == 'test'

    # Rate limiting (disabled in test to avoid test pollution)
    unless ENV['RACK_ENV'] == 'test'
      rate_limit_config = V7CMS.file_resolver.resolve('config/rate_limit.rb')
      if rate_limit_config
        require rate_limit_config
        use Rack::Attack
      end
    end

    # Security check: Warn if ADMIN_EMAILS not configured
    configure do
      if ENV['ADMIN_EMAILS'].nil? || ENV['ADMIN_EMAILS'].strip.empty?
        warn "=" * 80
        warn "WARNING: ADMIN_EMAILS environment variable is not set!"
        warn "Admin login is DISABLED until you configure authorized emails."
        warn "Add to .env file: ADMIN_EMAILS=your-email@example.com"
        warn "=" * 80
      end
    end

    # OmniAuth configuration - allow GET requests (required for OAuth links)
    OmniAuth.config.allowed_request_methods = [:get, :post]
    OmniAuth.config.silence_get_warning = true

    use OmniAuth::Builder do
      # Google OAuth - only request email to avoid ModSecurity blocking 'profile' keyword
      provider :google_oauth2,
        ENV['GOOGLE_CLIENT_ID'],
        ENV['GOOGLE_CLIENT_SECRET'],
        {
          scope: 'email',
          prompt: 'select_account',
          provider_ignores_state: true  # Disable CSRF state parameter check
        }

      # GitHub OAuth
      provider :github,
        ENV['GITHUB_CLIENT_ID'],
        ENV['GITHUB_CLIENT_SECRET'],
        scope: 'user:email'
    end

    # OmniAuth failure handling
    OmniAuth.config.on_failure = Proc.new do |env|
      OmniAuth::FailureEndpoint.new(env).redirect_to_failure
    end

    # Initialize theme CSS on startup if it doesn't exist
    configure do
      theme_css_path = File.join(settings.public_folder, 'css', 'theme.css')
      unless File.exist?(theme_css_path)
        theme = V7CMS::Theme.instance rescue nil
        V7CMS::ThemeGenerator.generate_and_write(theme) if theme
      end
    end

    # Custom error pages - check /error/ folder for static files
    # Checks for .html, .shtml, and .php extensions (in that order)
    # Only serve custom HTML for non-API routes (preserve JSON responses for API)
    ERROR_PAGE_EXTENSIONS = %w[.html .shtml .php].freeze

    # Helper to find custom error page file
    # Checks project root /error/ folder first, then gem's error folder
    def self.find_error_page(code)
      ERROR_PAGE_EXTENSIONS.each do |ext|
        # Use file_resolver to check project root first, then gem
        path = V7CMS.file_resolver.resolve(File.join('error', "#{code}#{ext}"))
        return path if path
      end
      nil
    end

    # Note: 404 errors are handled by the not_found block below (which also handles redirects)

    error 403 do
      # If response is already JSON (from API routes), don't override
      if response['Content-Type']&.include?('application/json')
        return response.body.join
      end

      error_file = self.class.find_error_page(403)
      if error_file
        content_type :html
        File.read(error_file)
      else
        "Forbidden"
      end
    end

    error 500 do
      # If response is already JSON (from API routes), don't override
      if response['Content-Type']&.include?('application/json')
        return response.body.join
      end

      error_file = self.class.find_error_page(500)
      if error_file
        content_type :html
        File.read(error_file)
      else
        "Internal Server Error"
      end
    end

    # Handle vanity URL redirects (for non-Apache deployments like Docker/Rack)
    # Apache handles these via .htaccess, but we need Sinatra fallback for Rack/Puma
    before do
      # Skip reserved paths - let them be handled by their respective routes
      return if request.path_info.start_with?('/api', '/auth', '/admin', '/feed', '/health', '/posts', '/pages')
      return if request.path_info == '/'
      return if request.path_info.include?('.')  # Skip static files

      # Check for redirect
      redirect_record = V7CMS::Redirect.find_by(short_path: request.path_info)
      if redirect_record
        redirect redirect_record.target_path, 301
      end
    end

    # =========================================================================
    # Admin Panel Routes (served from gem's public directory)
    # =========================================================================

    # Serve admin panel HTML - always from gem to ensure it's available
    get '/admin/' do
      admin_html = File.join(V7CMS.gem_root, 'lib', 'v7cms', 'public', 'admin', 'index.html')
      if File.exist?(admin_html)
        content_type 'text/html'
        File.read(admin_html)
      else
        halt 404, 'Admin panel not found'
      end
    end

    # Redirect /admin to /admin/
    get '/admin' do
      redirect '/admin/'
    end

    # Serve admin JS from gem's public directory
    get '/js/admin.js' do
      admin_js = File.join(V7CMS.gem_root, 'lib', 'v7cms', 'public', 'js', 'admin.js')
      if File.exist?(admin_js)
        content_type 'application/javascript'
        File.read(admin_js)
      else
        halt 404, 'Admin JS not found'
      end
    end

    # Serve comments JS from gem's public directory
    get '/js/comments.js' do
      comments_js = File.join(V7CMS.gem_root, 'lib', 'v7cms', 'public', 'js', 'comments.js')
      if File.exist?(comments_js)
        content_type 'application/javascript'
        File.read(comments_js)
      else
        halt 404, 'Comments JS not found'
      end
    end

    # Serve API docs from gem's public directory
    get '/api-docs.html' do
      api_docs = File.join(V7CMS.gem_root, 'lib', 'v7cms', 'public', 'api-docs.html')
      if File.exist?(api_docs)
        content_type 'text/html'
        File.read(api_docs)
      else
        halt 404, 'API docs not found'
      end
    end

    # =========================================================================
    # Public Site Routes
    # =========================================================================

    # Homepage - list all published posts
    get '/' do
      @posts = V7CMS::Post.published.recent
      @title = 'v7cms'
      erb :index
    end

    # View a single post by slug
    get '/posts/:slug' do
      @post = V7CMS::Post.find_by(slug: params[:slug])

      if @post.nil?
        status 404
        @title = '404 - Page Not Found'
        return erb :'404'
      end

      # Check if post has a published version
      published_version = @post.published_version

      if published_version.nil?
        # No published version - 404 for public, preview for admin
        if logged_in?
          @preview_mode = true
          @title = @post.title
          @post_content = @post.content
          @description = @post.content.to_s.gsub(/<[^>]*>/, '')[0..150]
        else
          status 404
          @title = '404 - Page Not Found'
          return erb :'404'
        end
      else
        # Serve published version content
        @title = published_version.title
        @post_content = published_version.content
        @description = published_version.content.to_s.gsub(/<[^>]*>/, '')[0..150]
      end

      @settings = V7CMS::Setting.instance

      # Use post layout from settings, default to 'standard'
      layout_name = @settings.layout_post.presence || 'standard'
      layout_path = "layouts/post/_#{layout_name}"

      # Check if layout template exists in any view path
      layout_exists = settings.views_paths.any? do |path|
        File.exist?(File.join(path, "#{layout_path}.erb"))
      end

      if layout_exists
        erb layout_path.to_sym, layout: :layout
      else
        erb :post, layout: :layout
      end
    end

    # View a page by slug (supports hierarchical paths like /parent/child)
    get '/pages/*' do
      slug_path = params[:splat].first

      # Try to find page by exact slug match first
      @page = V7CMS::Page.published.find_by(slug: slug_path)

      # If not found, try matching the last segment (for hierarchical URLs)
      if @page.nil?
        slug = slug_path.split('/').last
        @page = V7CMS::Page.published.find_by(slug: slug)
      end

      if @page.nil?
        status 404
        @title = '404 - Page Not Found'
        return erb :'404'
      end

      @title = @page.title
      @description = @page.content.to_s.gsub(/<[^>]*>/, '')[0..150]

      # Check if page uses a layout template (blog_grid, blog_list, etc.)
      if @page.uses_layout_template?
        @items = @page.items_for_display
        @posts = @items  # Backward compatibility until templates are updated
        @settings = V7CMS::Setting.instance  # Required for layout templates
        erb :"layouts/homepage/_#{@page.page_type}", layout: :layout
      else
        erb :page
      end
    end

    # RSS Feed - generate dynamically at /feed/rss
    get '/feed/rss' do
      content_type 'application/rss+xml', charset: 'utf-8'
      base_url = "#{request.scheme}://#{request.host_with_port}"
      V7CMS::FeedGenerator.new(base_url: base_url).generate_rss
    end

    # Atom Feed - generate dynamically at /feed/atom
    get '/feed/atom' do
      content_type 'application/atom+xml', charset: 'utf-8'
      base_url = "#{request.scheme}://#{request.host_with_port}"
      V7CMS::FeedGenerator.new(base_url: base_url).generate_atom
    end

    # =========================================================================
    # API Routes
    # =========================================================================

    # API route for backward compatibility
    get '/api' do
      json message: 'v7cms API - Coming soon'
    end

    # Health check endpoint
    get '/health' do
      db_status = begin
        ActiveRecord::Base.connection.active? ? 'connected' : 'disconnected'
      rescue => e
        'error'
      end
      json status: 'ok', database: db_status
    end

    # Version endpoint
    get '/api/version' do
      json version: V7CMS::VERSION
    end

    # API Documentation
    get '/api/docs' do
      redirect '/api-docs.html'
    end

    get '/api-spec.json' do
      # Try to load from app/docs first, then fall back to lib/v7cms/docs
      docs_path = File.join(V7CMS.gem_root, 'app', 'docs', 'api_docs.rb')
      require docs_path if File.exist?(docs_path)
      content_type :json
      ApiDocs.generate_spec.to_json
    end

    # =========================================================================
    # Authentication Routes (OAuth)
    # =========================================================================

    # OAuth callback (Google, GitHub, etc. all use this)
    get '/auth/:provider/callback' do
      auth = request.env['omniauth.auth']

      # Get admin email whitelist from environment
      admin_emails_raw = ENV['ADMIN_EMAILS']

      # Fail closed: reject if ADMIN_EMAILS not configured
      if admin_emails_raw.nil? || admin_emails_raw.strip.empty?
        halt 403, json({ error: 'Admin access not configured. Set ADMIN_EMAILS environment variable.' })
      end

      # Parse and normalize email list
      admin_emails = admin_emails_raw.split(',').map(&:strip)
      user_email = auth['info']['email']

      # Check if email is in whitelist
      unless admin_emails.include?(user_email)
        halt 403, json({ error: 'Your email is not authorized to access this admin panel.' })
      end

      # Email is authorized - create/update user with admin=true
      user = V7CMS::User.from_omniauth(auth)

      if user
        # Track last login time
        user.update!(last_login_at: Time.current)

        # Ensure admin flag is set
        user.update!(admin: true) unless user.admin?

        session[:user_id] = user.id
        redirect '/admin/'
      else
        halt 401, json({ error: 'Authentication failed' })
      end
    end

    # OAuth failure
    get '/auth/failure' do
      error_message = params[:message] || 'Authentication failed'
      halt 401, json({ error: error_message })
    end

    # Logout
    post '/api/auth/logout' do
      session.clear
      json({ success: true })
    end

    # Check auth status
    get '/api/auth/me' do
      if logged_in?
        json({
          logged_in: true,
          user: {
            id: current_user.id,
            email: current_user.email,
            name: current_user.name,
            avatar_url: current_user.avatar_url,
            provider: current_user.provider,
            admin: current_user.admin
          }
        })
      else
        json({ logged_in: false })
      end
    end

    # =========================================================================
    # Users API Routes
    # =========================================================================

    # GET /api/users - List all users
    get '/api/users' do
      require_login
      users = V7CMS::User.order(created_at: :desc)
      json({ users: users.map { |u| user_json(u) } })
    end

    # PUT /api/users/:id - Update user (admin status)
    put '/api/users/:id' do
      require_ajax_header
      require_login

      user = V7CMS::User.find_by(id: params[:id])
      halt 404, json({ error: 'User not found' }) unless user

      begin
        data = JSON.parse(request.body.read)
      rescue JSON::ParserError
        halt 422, json({ errors: ['Invalid JSON'] })
      end

      # Only allow updating admin field
      if data.key?('admin')
        new_admin_value = data['admin']

        # Safety: Can't revoke own admin access
        if user.id == current_user.id && new_admin_value == false
          halt 400, json({ error: 'Cannot revoke your own admin access' })
        end

        # Safety: Must keep at least one admin
        if new_admin_value == false && V7CMS::User.where(admin: true).one? && user.admin?
          halt 400, json({ error: 'Cannot revoke - at least one admin must remain' })
        end

        user.update!(admin: new_admin_value)
      end

      json({ user: user_json(user) })
    end

    # =========================================================================
    # Posts API Routes
    # =========================================================================

    # GET /api/posts - List posts
    get '/api/posts' do
      # Apply filters
      posts_scope = if logged_in? && params[:include_drafts] == 'true'
        V7CMS::Post.recent
      else
        V7CMS::Post.published.recent
      end

      # Apply slug filter if provided
      posts_scope = posts_scope.where(slug: params[:slug]) if params[:slug]

      # Get pagination params
      page_params = pagination_params

      # Get total before pagination
      total = posts_scope.count

      # Apply pagination
      posts = posts_scope.limit(page_params[:limit]).offset(page_params[:offset])

      # Build response with metadata
      json({
        posts: posts.map { |p| post_json(p) },
        pagination: pagination_metadata(
          total: total,
          limit: page_params[:limit],
          offset: page_params[:offset],
          count: posts.length
        )
      })
    end

    # GET /api/posts/:id - Get a single post by ID or slug
    get '/api/posts/:id' do
      post = V7CMS::Post.find_by(id: params[:id]) || V7CMS::Post.find_by(slug: params[:id])

      if post.nil?
        halt 404, json({ error: 'Post not found' })
      end

      # Only allow viewing unpublished posts if logged in
      if !post.published? && !logged_in?
        halt 404, json({ error: 'Post not found' })
      end

      json({ post: post_json(post) })
    end

    # POST /api/posts - Create a new post
    post '/api/posts' do
      require_ajax_header
      require_login

      begin
        data = JSON.parse(request.body.read)
      rescue JSON::ParserError
        halt 422, json({ errors: ['Invalid JSON'] })
      end

      post = V7CMS::Post.new(
        title: data['title'],
        slug: data['slug'],
        content: data['content'],
        status: data['status'] || 'draft',
        comments_enabled: data.key?('comments_enabled') ? data['comments_enabled'] : true
      )

      if post.save
        if data.key?('tag_ids') && data['tag_ids'].is_a?(Array)
          valid_tags = V7CMS::Tag.where(id: data['tag_ids'])
          post.tags = valid_tags
        end
        status 201
        json({ post: post_json(post) })
      else
        halt 422, json({ errors: post.errors.full_messages })
      end
    end

    # PUT /api/posts/:id - Update a post
    put '/api/posts/:id' do
      require_ajax_header
      require_login

      post = V7CMS::Post.find_by(id: params[:id])

      if post.nil?
        halt 404, json({ error: 'Post not found' })
      end

      begin
        data = JSON.parse(request.body.read)
      rescue JSON::ParserError
        halt 422, json({ errors: ['Invalid JSON'] })
      end

      # Update only provided fields
      post.title = data['title'] if data.key?('title')
      post.slug = data['slug'] if data.key?('slug')
      post.content = data['content'] if data.key?('content')
      post.status = data['status'] if data.key?('status')
      post.comments_enabled = data['comments_enabled'] if data.key?('comments_enabled')

      if post.save
        if data.key?('tag_ids') && data['tag_ids'].is_a?(Array)
          valid_tags = V7CMS::Tag.where(id: data['tag_ids'])
          post.tags = valid_tags
        end
        json({ post: post_json(post) })
      else
        halt 422, json({ errors: post.errors.full_messages })
      end
    end

    # DELETE /api/posts/:id - Delete a post
    delete '/api/posts/:id' do
      require_ajax_header
      require_login

      post = V7CMS::Post.find_by(id: params[:id])

      if post.nil?
        halt 404, json({ error: 'Post not found' })
      end

      post.destroy
      status 204
    end

    # PUT /api/posts/:id/status - Update post status (draft/ready)
    put '/api/posts/:id/status' do
      require_ajax_header
      require_login

      post = V7CMS::Post.find_by(id: params[:id])
      halt 404, json({ error: 'Post not found' }) unless post

      begin
        data = JSON.parse(request.body.read)
      rescue JSON::ParserError
        halt 422, json({ errors: ['Invalid JSON'] })
      end

      new_status = data['status']
      unless %w[draft ready].include?(new_status)
        halt 422, json({ errors: ['Invalid status. Must be draft or ready.'] })
      end

      if post.update(status: new_status)
        json({ post: post_json(post) })
      else
        halt 422, json({ errors: post.errors.full_messages })
      end
    end

    # POST /api/posts/:id/publish - Publish a post
    post '/api/posts/:id/publish' do
      require_ajax_header
      require_login

      post = V7CMS::Post.find_by(id: params[:id])
      halt 404, json({ error: 'Post not found' }) unless post

      post.publish!
      json({ post: post_json(post) })
    end

    # POST /api/posts/:id/unpublish - Unpublish a post
    post '/api/posts/:id/unpublish' do
      require_ajax_header
      require_login

      post = V7CMS::Post.find_by(id: params[:id])
      halt 404, json({ error: 'Post not found' }) unless post

      post.unpublish!
      json({ post: post_json(post) })
    end

    # =========================================================================
    # Settings API Routes
    # =========================================================================

    # GET /api/settings - Get current settings (no auth required for public display)
    get '/api/settings' do
      settings = V7CMS::Setting.instance
      json({ settings: settings_json(settings) })
    end

    # PUT /api/settings - Update settings (auth required)
    put '/api/settings' do
      require_ajax_header
      require_login

      settings = V7CMS::Setting.instance

      begin
        data = JSON.parse(request.body.read)
      rescue JSON::ParserError
        halt 422, json({ errors: ['Invalid JSON'] })
      end

      if settings.update(data)
        json({ settings: settings_json(settings) })
      else
        halt 422, json({ errors: settings.errors.full_messages })
      end
    end

    # POST /api/settings/reset - Reset to defaults (auth required)
    post '/api/settings/reset' do
      require_ajax_header
      require_login

      settings = V7CMS::Setting.instance
      settings.reset_to_defaults!

      json({ settings: settings_json(settings) })
    end

    # GET /api/settings/layouts - Get available homepage layouts
    get '/api/settings/layouts' do
      layouts = V7CMS::Setting.available_layouts.map do |name|
        {
          name: name,
          label: name.split('_').map(&:capitalize).join(' '),
          builtin: V7CMS::Setting::HOMEPAGE_LAYOUTS.include?(name)
        }
      end
      json({ layouts: layouts })
    end

    # GET /api/settings/post-layouts - List available post layouts
    get '/api/settings/post-layouts' do
      layouts = V7CMS::Setting.available_post_layouts.map do |name|
        {
          name: name,
          label: name.split('_').map(&:capitalize).join(' '),
          builtin: V7CMS::Setting::POST_LAYOUTS.include?(name)
        }
      end
      json({ layouts: layouts })
    end

    # =========================================================================
    # Theme API Routes
    # =========================================================================

    # GET /api/theme - Get current theme (no auth required for public display)
    get '/api/theme' do
      theme = V7CMS::Theme.instance
      json({ theme: theme_json(theme) })
    end

    # PUT /api/theme - Update theme (auth required)
    put '/api/theme' do
      require_ajax_header
      require_login

      theme = V7CMS::Theme.instance

      begin
        data = JSON.parse(request.body.read)
      rescue JSON::ParserError
        halt 422, json({ errors: ['Invalid JSON'] })
      end

      if theme.update(data)
        json({ theme: theme_json(theme) })
      else
        halt 422, json({ errors: theme.errors.full_messages })
      end
    end

    # POST /api/theme/reset - Reset to defaults (auth required)
    post '/api/theme/reset' do
      require_ajax_header
      require_login

      theme = V7CMS::Theme.instance
      theme.reset_to_defaults!

      json({ theme: theme_json(theme) })
    end

    # GET /api/theme/preview - Preview theme with temporary parameters (no auth, public)
    # Renders an actual page with theme params applied for live preview in iframe
    get '/api/theme/preview' do
      # Set flag so generate_theme_css uses query params instead of database
      params[:theme_preview] = true

      # Get the page to preview (default to homepage)
      preview_page = params[:page] || '/'

      # Render the appropriate page based on the path
      case preview_page
      when '/'
        # Homepage
        @posts = V7CMS::Post.published.recent.limit(5)
        @title = 'Theme Preview - Home'
        erb :index
      when %r{^/posts/(.+)$}
        # Single post
        slug = $1
        @post = V7CMS::Post.published.find_by(slug: slug) || V7CMS::Post.published.first
        if @post
          @title = "Theme Preview - #{@post.title}"
          erb :post
        else
          @posts = []
          @title = 'Theme Preview - Home'
          erb :index
        end
      when %r{^/pages/(.+)$}
        # Static page
        slug = $1
        @page = V7CMS::Page.published.find_by(slug: slug) || V7CMS::Page.published.first
        if @page
          @title = "Theme Preview - #{@page.title}"
          erb :page
        else
          @posts = []
          @title = 'Theme Preview - Home'
          erb :index
        end
      else
        # Default to homepage for unknown paths
        @posts = V7CMS::Post.published.recent.limit(5)
        @title = 'Theme Preview - Home'
        erb :index
      end
    end

    # =========================================================================
    # Redirects API Routes
    # =========================================================================

    # GET /api/redirects - List all redirects
    get '/api/redirects' do
      require_ajax_header
      require_login
      json({ redirects: V7CMS::Redirect.order(:short_path).map { |r| redirect_json(r) } })
    end

    # POST /api/redirects - Create redirect
    post '/api/redirects' do
      require_ajax_header
      require_login

      begin
        data = JSON.parse(request.body.read)
      rescue JSON::ParserError
        halt 422, json({ errors: ['Invalid JSON'] })
      end

      redirect = V7CMS::Redirect.new(short_path: data['short_path'], target_path: data['target_path'])

      if redirect.save
        json({ redirect: redirect_json(redirect) })
      else
        halt 422, json({ errors: redirect.errors.full_messages })
      end
    end

    # PUT /api/redirects/:id - Update redirect
    put '/api/redirects/:id' do
      require_ajax_header
      require_login

      redirect = V7CMS::Redirect.find_by(id: params[:id])
      halt 404, json({ error: 'Redirect not found' }) unless redirect

      begin
        data = JSON.parse(request.body.read)
      rescue JSON::ParserError
        halt 422, json({ errors: ['Invalid JSON'] })
      end

      if redirect.update(short_path: data['short_path'], target_path: data['target_path'])
        json({ redirect: redirect_json(redirect) })
      else
        halt 422, json({ errors: redirect.errors.full_messages })
      end
    end

    # DELETE /api/redirects/:id - Delete redirect
    delete '/api/redirects/:id' do
      require_ajax_header
      require_login

      redirect = V7CMS::Redirect.find_by(id: params[:id])
      halt 404, json({ error: 'Redirect not found' }) unless redirect

      redirect.destroy
      json({ success: true })
    end

    # =========================================================================
    # Tags API Routes
    # =========================================================================

    # GET /api/tags - List all tags
    get '/api/tags' do
      tags = V7CMS::Tag.ordered.left_joins(:posts).group(:id).select('tags.*, COUNT(posts.id) AS cached_posts_count')
      json({ tags: tags.map { |t| tag_json(t) } })
    end

    # POST /api/tags - Create a tag
    post '/api/tags' do
      require_ajax_header
      require_login

      begin
        data = JSON.parse(request.body.read)
      rescue JSON::ParserError
        halt 422, json({ errors: ['Invalid JSON'] })
      end

      tag = V7CMS::Tag.new(name: data['name'])

      if tag.save
        status 201
        json({ tag: tag_json(tag) })
      else
        halt 422, json({ errors: tag.errors.full_messages })
      end
    end

    # PUT /api/tags/:id - Rename a tag
    put '/api/tags/:id' do
      require_ajax_header
      require_login

      tag = V7CMS::Tag.find_by(id: params[:id])
      halt 404, json({ error: 'Tag not found' }) unless tag

      begin
        data = JSON.parse(request.body.read)
      rescue JSON::ParserError
        halt 422, json({ errors: ['Invalid JSON'] })
      end

      tag.name = data['name'] if data.key?('name')

      if tag.save
        json({ tag: tag_json(tag) })
      else
        halt 422, json({ errors: tag.errors.full_messages })
      end
    end

    # DELETE /api/tags/:id - Delete a tag
    delete '/api/tags/:id' do
      require_ajax_header
      require_login

      tag = V7CMS::Tag.find_by(id: params[:id])
      halt 404, json({ error: 'Tag not found' }) unless tag

      count = tag.posts.count
      if count > 0
        halt 409, json({ error: "Cannot delete tag with #{count} posts. Remove the tag from all posts first." })
      end

      # Nullify any pages using this tag as content filter
      V7CMS::Page.where(content_filter_tag_id: tag.id).update_all(content_filter_tag_id: nil)

      tag.destroy
      status 204
      body ''
    end

    # =========================================================================
    # Pages API Routes
    # =========================================================================

    # GET /api/pages - List pages
    get '/api/pages' do
      # Apply filters
      pages_scope = if logged_in? && params[:include_drafts] == 'true'
        V7CMS::Page.ordered
      else
        V7CMS::Page.published.ordered
      end

      # Return hierarchical structure when nested=true
      if params[:nested] == 'true'
        top_level_pages = pages_scope.top_level
        return json({
          pages: top_level_pages.map { |page| page_json_nested(page, 0, pages_scope) }
        })
      end

      # Apply top_level filter if requested
      pages_scope = pages_scope.top_level if params[:top_level] == 'true'

      # Support parent filtering
      pages_scope = pages_scope.where(parent_id: params[:parent_id]) if params[:parent_id]

      # Apply slug filter if provided
      pages_scope = pages_scope.where(slug: params[:slug]) if params[:slug]

      # Get pagination params
      page_params = pagination_params

      # Get total before pagination
      total = pages_scope.count

      # Apply pagination
      pages = pages_scope.limit(page_params[:limit]).offset(page_params[:offset])

      # Build response with metadata
      json({
        pages: pages.map { |page| page_json(page) },
        pagination: pagination_metadata(
          total: total,
          limit: page_params[:limit],
          offset: page_params[:offset],
          count: pages.length
        )
      })
    end

    # GET /api/pages/types - Get available page types
    get '/api/pages/types' do
      static_types = V7CMS::Page::STATIC_PAGE_TYPES.map do |name|
        { name: name, label: name.capitalize, category: 'static' }
      end

      layout_types = V7CMS::Page::LAYOUT_PAGE_TYPES.map do |name|
        { name: name, label: name.split('_').map(&:capitalize).join(' '), category: 'layout' }
      end

      json({ types: static_types + layout_types })
    end

    # GET /api/pages/:id - Get a single page by ID or slug
    get '/api/pages/:id' do
      page = V7CMS::Page.find_by(id: params[:id]) || V7CMS::Page.find_by(slug: params[:id])

      if page.nil?
        halt 404, json({ error: 'Page not found' })
      end

      # Only allow viewing unpublished pages if logged in
      if !page.published? && !logged_in?
        halt 404, json({ error: 'Page not found' })
      end

      json({ page: page_json(page, include_relations: true) })
    end

    # POST /api/pages - Create a new page
    post '/api/pages' do
      require_ajax_header
      require_login

      begin
        data = JSON.parse(request.body.read)
      rescue JSON::ParserError
        halt 422, json({ errors: ['Invalid JSON'] })
      end

      if data['content_filter_tag_id'].present? && !V7CMS::Tag.exists?(data['content_filter_tag_id'])
        halt 422, json({ errors: ['Content filter tag not found'] })
      end

      page = V7CMS::Page.new(
        title: data['title'],
        slug: data['slug'],
        content: data['content'],
        status: data['status'] || 'draft',
        parent_id: data['parent_id'],
        position: data['position'] || 0,
        page_type: data['page_type'] || 'standard',
        content_source: data['content_source'] || 'children',
        items_limit: data['items_limit'] || 10,
        hero_image_url: data['hero_image_url'],
        content_filter_tag_id: data['content_filter_tag_id']
      )

      if page.save
        status 201
        json({ page: page_json(page, include_relations: true) })
      else
        halt 422, json({ errors: page.errors.full_messages })
      end
    end

    # PUT /api/pages/:id - Update a page
    put '/api/pages/:id' do
      require_ajax_header
      require_login

      page = V7CMS::Page.find_by(id: params[:id])

      if page.nil?
        halt 404, json({ error: 'Page not found' })
      end

      begin
        data = JSON.parse(request.body.read)
      rescue JSON::ParserError
        halt 422, json({ errors: ['Invalid JSON'] })
      end

      # Update only provided fields
      page.title = data['title'] if data.key?('title')
      page.slug = data['slug'] if data.key?('slug')
      page.content = data['content'] if data.key?('content')
      page.status = data['status'] if data.key?('status')
      page.parent_id = data['parent_id'] if data.key?('parent_id')
      page.position = data['position'] if data.key?('position')
      page.page_type = data['page_type'] if data.key?('page_type')
      page.content_source = data['content_source'] if data.key?('content_source')
      page.items_limit = data['items_limit'] if data.key?('items_limit')
      page.hero_image_url = data['hero_image_url'] if data.key?('hero_image_url')
      if data.key?('content_filter_tag_id')
        if data['content_filter_tag_id'].present? && !V7CMS::Tag.exists?(data['content_filter_tag_id'])
          halt 422, json({ errors: ['Content filter tag not found'] })
        end
        page.content_filter_tag_id = data['content_filter_tag_id']
      end

      if page.save
        json({ page: page_json(page, include_relations: true) })
      else
        halt 422, json({ errors: page.errors.full_messages })
      end
    end

    # DELETE /api/pages/:id - Delete a page
    delete '/api/pages/:id' do
      require_ajax_header
      require_login

      page = V7CMS::Page.find_by(id: params[:id])

      if page.nil?
        halt 404, json({ error: 'Page not found' })
      end

      page.destroy
      status 204
    end

    # PUT /api/pages/:id/status - Update page status
    put '/api/pages/:id/status' do
      require_ajax_header
      require_login

      page = V7CMS::Page.find_by(id: params[:id])
      halt 404, json({ error: 'Page not found' }) unless page

      begin
        data = JSON.parse(request.body.read)
      rescue JSON::ParserError
        halt 422, json({ errors: ['Invalid JSON'] })
      end

      new_status = data['status']
      unless V7CMS::Page::STATUSES.include?(new_status)
        halt 422, json({ errors: ["Invalid status. Must be one of: #{V7CMS::Page::STATUSES.join(', ')}"] })
      end

      if page.update(status: new_status)
        json({ page: page_json(page, include_relations: true) })
      else
        halt 422, json({ errors: page.errors.full_messages })
      end
    end

    # POST /api/pages/:id/publish - Publish a page
    post '/api/pages/:id/publish' do
      require_ajax_header
      require_login

      page = V7CMS::Page.find_by(id: params[:id])
      halt 404, json({ error: 'Page not found' }) unless page

      page.publish!
      json({ page: page_json(page, include_relations: true) })
    end

    # POST /api/pages/:id/unpublish - Unpublish a page
    post '/api/pages/:id/unpublish' do
      require_ajax_header
      require_login

      page = V7CMS::Page.find_by(id: params[:id])
      halt 404, json({ error: 'Page not found' }) unless page

      page.unpublish!
      json({ page: page_json(page, include_relations: true) })
    end

    # =========================================================================
    # Version History API Routes
    # =========================================================================

    # GET /api/posts/:id/versions - List versions for a post
    get '/api/posts/:id/versions' do
      require_login

      post = V7CMS::Post.find_by(id: params[:id])
      halt 404, json({ error: 'Post not found' }) unless post

      versions = if params[:all] == 'true'
        post.content_versions
      else
        post.content_versions.permanent
      end

      json({
        versions: versions.map { |v| version_json(v) }
      })
    end

    # GET /api/pages/:id/versions - List versions for a page
    get '/api/pages/:id/versions' do
      require_login

      page = V7CMS::Page.find_by(id: params[:id])
      halt 404, json({ error: 'Page not found' }) unless page

      versions = if params[:all] == 'true'
        page.content_versions
      else
        page.content_versions.permanent
      end

      json({
        versions: versions.map { |v| version_json(v) }
      })
    end

    # GET /api/posts/:id/versions/:num - Get specific version with content
    get '/api/posts/:id/versions/:num' do
      require_login

      post = V7CMS::Post.find_by(id: params[:id])
      halt 404, json({ error: 'Post not found' }) unless post

      version = post.version_at(params[:num].to_i)
      halt 404, json({ error: 'Version not found' }) unless version

      json({ version: version_json(version, include_content: true) })
    end

    # GET /api/pages/:id/versions/:num - Get specific version with content
    get '/api/pages/:id/versions/:num' do
      require_login

      page = V7CMS::Page.find_by(id: params[:id])
      halt 404, json({ error: 'Page not found' }) unless page

      version = page.version_at(params[:num].to_i)
      halt 404, json({ error: 'Version not found' }) unless version

      json({ version: version_json(version, include_content: true) })
    end

    # POST /api/posts/:id/versions/:num/restore - Restore post to version
    post '/api/posts/:id/versions/:num/restore' do
      require_ajax_header
      require_login

      post_record = V7CMS::Post.find_by(id: params[:id])
      halt 404, json({ error: 'Post not found' }) unless post_record

      begin
        post_record.restore_version!(params[:num].to_i)
        post_record.reload
        json({ post: post_json(post_record) })
      rescue ActiveRecord::RecordNotFound => e
        halt 404, json({ error: e.message })
      end
    end

    # POST /api/pages/:id/versions/:num/restore - Restore page to version
    post '/api/pages/:id/versions/:num/restore' do
      require_ajax_header
      require_login

      page = V7CMS::Page.find_by(id: params[:id])
      halt 404, json({ error: 'Page not found' }) unless page

      begin
        page.restore_version!(params[:num].to_i)
        page.reload
        json({ page: page_json(page) })
      rescue ActiveRecord::RecordNotFound => e
        halt 404, json({ error: e.message })
      end
    end

    # POST /api/posts/:id/versions/:num/keep - Mark version as permanent
    post '/api/posts/:id/versions/:num/keep' do
      require_ajax_header
      require_login

      post_record = V7CMS::Post.find_by(id: params[:id])
      halt 404, json({ error: 'Post not found' }) unless post_record

      version = post_record.version_at(params[:num].to_i)
      halt 404, json({ error: 'Version not found' }) unless version

      version.mark_permanent!
      json({ version: version_json(version) })
    end

    # POST /api/pages/:id/versions/:num/keep - Mark version as permanent
    post '/api/pages/:id/versions/:num/keep' do
      require_ajax_header
      require_login

      page = V7CMS::Page.find_by(id: params[:id])
      halt 404, json({ error: 'Page not found' }) unless page

      version = page.version_at(params[:num].to_i)
      halt 404, json({ error: 'Version not found' }) unless version

      version.mark_permanent!
      json({ version: version_json(version) })
    end

    # =========================================================================
    # Comments API Routes
    # =========================================================================

    # GET /api/posts/:id/comments - List approved comments for a post (public)
    get '/api/posts/:id/comments' do
      post = V7CMS::Post.find_by(id: params[:id])
      halt 404, json({ error: 'Post not found' }) unless post

      limit = [params[:limit].to_i, 1].max
      limit = [limit, 100].min # Cap at 100
      limit = 20 if limit == 0 || params[:limit].nil?

      offset = [params[:offset].to_i, 0].max

      comments = post.comments.approved.order(created_at: :asc).limit(limit).offset(offset)
      total = post.comments.approved.count

      json({
        comments: comments.map { |c| comment_json(c) },
        pagination: {
          total: total,
          limit: limit,
          offset: offset,
          has_more: (offset + limit) < total
        }
      })
    end

    # POST /api/posts/:id/comments - Submit a new comment (public, requires reCAPTCHA)
    post '/api/posts/:id/comments' do
      post_record = V7CMS::Post.find_by(id: params[:id])
      halt 404, json({ error: 'Post not found' }) unless post_record

      # Check if comments are allowed
      halt 403, json({ error: 'Comments are closed for this post' }) unless post_record.comments_allowed?

      data = JSON.parse(request.body.read)
      recaptcha_token = data['recaptcha_token']

      # Verify reCAPTCHA
      recaptcha_score = verify_recaptcha_v3(recaptcha_token, request.ip)

      # Reject if score too low (likely bot)
      if recaptcha_score < 0.5
        halt 400, json({ error: 'reCAPTCHA verification failed. Please try again.' })
      end

      # Create comment
      comment = post_record.comments.build(
        author_name: data['author_name'],
        author_email: data['author_email'],
        author_url: data['author_url'],
        content: data['content'],
        ip_address: request.ip,
        recaptcha_score: recaptcha_score,
        approved: false # Requires moderation
      )

      if comment.save
        json({ success: true, message: 'Comment submitted for moderation. It will appear after approval.' })
      else
        halt 400, json({ error: comment.errors.full_messages.join(', ') })
      end
    end

    # GET /api/comments - List all comments with filters (admin only)
    get '/api/comments' do
      require_login

      status_filter = params[:status] # 'pending', 'approved', 'spam', or nil for all

      comments = case status_filter
      when 'pending'
        V7CMS::Comment.pending
      when 'approved'
        V7CMS::Comment.approved
      when 'spam'
        V7CMS::Comment.spam
      else
        V7CMS::Comment.all
      end

      comments = comments.includes(:post).order(created_at: :desc)

      json({
        comments: comments.map { |c| admin_comment_json(c) }
      })
    end

    # GET /api/comments/pending_count - Get count of pending comments (public for badge)
    get '/api/comments/pending_count' do
      json({ count: V7CMS::Comment.pending_count })
    end

    # PUT /api/comments/:id/approve - Approve a comment (admin only)
    put '/api/comments/:id/approve' do
      require_login

      comment = V7CMS::Comment.find_by(id: params[:id])
      halt 404, json({ error: 'Comment not found' }) unless comment
      comment.update!(approved: true, spam: false)

      json({ success: true, comment: admin_comment_json(comment) })
    end

    # PUT /api/comments/:id/spam - Mark comment as spam (admin only)
    put '/api/comments/:id/spam' do
      require_login

      comment = V7CMS::Comment.find_by(id: params[:id])
      halt 404, json({ error: 'Comment not found' }) unless comment
      comment.update!(spam: true, approved: false)

      json({ success: true, comment: admin_comment_json(comment) })
    end

    # DELETE /api/comments/:id - Delete a comment permanently (admin only)
    delete '/api/comments/:id' do
      require_login

      comment = V7CMS::Comment.find_by(id: params[:id])
      halt 404, json({ error: 'Comment not found' }) unless comment
      comment.destroy

      json({ success: true })
    end

    # ============================================================================
    # Upload File Serving Route
    # ============================================================================

    # GET /upload/* - Serve uploaded files with optional transformations
    get '/upload/*' do
      path = params[:splat].first
      adapter = V7CMS::Asset.storage_adapter

      # Check if file exists
      unless adapter.exists?(path)
        halt 404, 'File not found'
      end

      # Parse transform params
      transform_params = V7CMS::ImageTransformer.parse_params(params)
      cache_key = V7CMS::ImageTransformer.cache_key(transform_params)

      file_path = File.join(adapter.base_path, path)

      # If transforms requested and available, try to serve/create cached version
      if cache_key && V7CMS::ImageTransformer.available?
        cache_dir = File.join(adapter.base_path, '.cache', cache_key)
        cached_path = File.join(cache_dir, path)

        unless File.exist?(cached_path)
          V7CMS::ImageTransformer.transform(file_path, transform_params, cached_path)
        end

        if File.exist?(cached_path)
          file_path = cached_path
        end
      end

      # Determine content type
      ext = File.extname(path).downcase
      content_type = case ext
                     when '.jpg', '.jpeg' then 'image/jpeg'
                     when '.png' then 'image/png'
                     when '.gif' then 'image/gif'
                     when '.webp' then 'image/webp'
                     when '.svg' then 'image/svg+xml'
                     when '.pdf' then 'application/pdf'
                     when '.mp3' then 'audio/mpeg'
                     when '.mp4' then 'video/mp4'
                     when '.zip' then 'application/zip'
                     when '.doc' then 'application/msword'
                     when '.docx' then 'application/vnd.openxmlformats-officedocument.wordprocessingml.document'
                     when '.xls' then 'application/vnd.ms-excel'
                     when '.xlsx' then 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
                     else 'application/octet-stream'
                     end

      content_type content_type
      send_file file_path
    end

    # =========================================================================
    # Assets API Routes
    # =========================================================================

    # Helper for asset JSON serialization
    def asset_json(asset)
      {
        id: asset.id,
        filename: asset.filename,
        original_filename: asset.original_filename,
        url: asset.url,
        content_type: asset.content_type,
        file_size: asset.file_size,
        width: asset.width,
        height: asset.height,
        alt_text: asset.alt_text,
        type: asset.file_type_category,
        created_at: asset.created_at.iso8601,
        uploaded_by: asset.uploaded_by&.name
      }
    end

    # GET /api/assets/capabilities - Check asset system capabilities
    get '/api/assets/capabilities' do
      json({
        image_processing: V7CMS::ImageTransformer.available?,
        max_upload_size: V7CMS::Setting.instance.max_upload_size
      })
    end

    # GET /api/assets - List assets with pagination and filtering
    get '/api/assets' do
      page = (params[:page] || 1).to_i
      per_page = [[params[:per_page].to_i, 1].max, 100].min
      per_page = 20 if per_page == 0

      assets = V7CMS::Asset.all

      # Filter by type
      case params[:type]
      when 'image'
        assets = assets.images
      when 'document'
        assets = assets.documents
      when 'audio'
        assets = assets.audio
      when 'video'
        assets = assets.video
      when 'archive'
        assets = assets.archives
      end

      # Search by filename
      if params[:search].present?
        search_term = "%#{params[:search]}%"
        assets = assets.where('filename LIKE ? OR original_filename LIKE ?', search_term, search_term)
      end

      # Sorting
      assets = case params[:sort]
               when 'oldest'
                 assets.order(created_at: :asc)
               when 'filename'
                 assets.order(filename: :asc)
               when 'size'
                 assets.order(file_size: :desc)
               else
                 assets.recent
               end

      total = assets.count
      assets = assets.offset((page - 1) * per_page).limit(per_page)

      json({
        assets: assets.map { |a| asset_json(a) },
        pagination: {
          page: page,
          per_page: per_page,
          total: total,
          pages: (total.to_f / per_page).ceil
        }
      })
    end

    # GET /api/assets/:id - Get single asset
    get '/api/assets/:id' do
      asset = V7CMS::Asset.find_by(id: params[:id])
      halt 404, json({ error: 'Asset not found' }) unless asset

      json(asset_json(asset))
    end

    # POST /api/assets - Upload new asset
    post '/api/assets' do
      require_login

      unless params[:file] && params[:file][:tempfile]
        halt 400, json({ error: 'No file provided' })
      end

      file = params[:file][:tempfile]
      original_filename = params[:file][:filename]
      content_type = params[:file][:type] || 'application/octet-stream'
      file_size = file.size

      # Validate file size
      max_size = V7CMS::Setting.instance.max_upload_size
      if file_size > max_size
        halt 400, json({ error: "File too large. Maximum size is #{max_size / 1_048_576}MB" })
      end

      # Validate content type
      unless V7CMS::Asset::ALLOWED_CONTENT_TYPES.include?(content_type)
        halt 400, json({ error: 'File type not allowed' })
      end

      # Generate unique storage key
      adapter = V7CMS::Asset.storage_adapter
      storage_key = adapter.generate_unique_key(original_filename)

      # Store file
      adapter.store(file, storage_key)

      # Get image dimensions if applicable
      width, height = nil, nil
      if content_type.start_with?('image/') && !content_type.include?('svg')
        begin
          require 'fastimage'
          size = FastImage.size(File.join(adapter.base_path, storage_key))
          width, height = size if size
        rescue => e
          warn "Failed to get image dimensions: #{e.message}"
        end
      end

      # Create asset record
      asset = V7CMS::Asset.create!(
        filename: File.basename(storage_key),
        original_filename: original_filename,
        content_type: content_type,
        file_size: file_size,
        storage_key: storage_key,
        width: width,
        height: height,
        uploaded_by: current_user
      )

      status 201
      json(asset_json(asset))
    end

    # PUT /api/assets/:id - Update asset metadata
    put '/api/assets/:id' do
      require_login

      asset = V7CMS::Asset.find_by(id: params[:id])
      halt 404, json({ error: 'Asset not found' }) unless asset

      data = JSON.parse(request.body.read) rescue {}

      # Only allow updating alt_text
      if data.key?('alt_text')
        asset.update!(alt_text: data['alt_text'])
      end

      json(asset_json(asset))
    end

    # DELETE /api/assets/:id - Delete asset
    delete '/api/assets/:id' do
      require_login

      asset = V7CMS::Asset.find_by(id: params[:id])
      halt 404, json({ error: 'Asset not found' }) unless asset

      # Delete file from storage
      adapter = V7CMS::Asset.storage_adapter
      adapter.delete(asset.storage_key)

      # Delete database record
      asset.destroy!

      json({ success: true })
    end

    # =========================================================================
    # Menus API Routes
    # =========================================================================

    # Menu serialization helper
    def menu_json(menu, include_items: false)
      result = {
        id: menu.id,
        name: menu.name,
        slug: menu.slug,
        location: menu.location,
        item_count: menu.menu_items.count,
        created_at: menu.created_at&.iso8601
      }
      result[:items] = menu.nested_items if include_items
      result
    end

    # Menu item serialization helper
    def menu_item_json(item)
      {
        id: item.id,
        menu_id: item.menu_id,
        label: item.label,
        link_type: item.link_type,
        linkable_type: item.linkable_type,
        linkable_id: item.linkable_id,
        url: item.url,
        href: item.href,
        target: item.target,
        parent_id: item.parent_id,
        position: item.position
      }
    end

    # GET /api/menus - List all menus
    get '/api/menus' do
      require_login

      menus = V7CMS::Menu.all.order(:name)
      json({ menus: menus.map { |m| menu_json(m) } })
    end

    # GET /api/menus/:slug/render - Render menu HTML (public, no auth)
    get '/api/menus/:slug/render' do
      menu = V7CMS::Menu.at_location(params[:slug]) || V7CMS::Menu.by_slug(params[:slug])
      halt 404, json({ error: 'Menu not found' }) unless menu

      html = V7CMS::MenuHelper.render_menu(params[:slug])
      json({ html: html })
    end

    # GET /api/menus/:id - Get menu by id or slug with nested items
    get '/api/menus/:id' do
      require_login

      menu = V7CMS::Menu.find_by(id: params[:id]) || V7CMS::Menu.by_slug(params[:id])
      halt 404, json({ error: 'Menu not found' }) unless menu

      json({ menu: menu_json(menu, include_items: true) })
    end

    # POST /api/menus - Create menu
    post '/api/menus' do
      require_ajax_header
      require_login

      data = JSON.parse(request.body.read)
      menu = V7CMS::Menu.new(
        name: data['name'],
        slug: data['slug'],
        location: data['location']
      )

      if menu.save
        status 201
        json({ menu: menu_json(menu) })
      else
        halt 422, json({ errors: menu.errors.full_messages })
      end
    end

    # PUT /api/menus/:id - Update menu
    put '/api/menus/:id' do
      require_ajax_header
      require_login

      menu = V7CMS::Menu.find_by(id: params[:id])
      halt 404, json({ error: 'Menu not found' }) unless menu

      data = JSON.parse(request.body.read)
      updates = {}
      updates[:name] = data['name'] if data.key?('name')
      updates[:slug] = data['slug'] if data.key?('slug')
      updates[:location] = data['location'] if data.key?('location')

      if menu.update(updates)
        json({ menu: menu_json(menu) })
      else
        halt 422, json({ errors: menu.errors.full_messages })
      end
    end

    # DELETE /api/menus/:id - Delete menu
    delete '/api/menus/:id' do
      require_ajax_header
      require_login

      menu = V7CMS::Menu.find_by(id: params[:id])
      halt 404, json({ error: 'Menu not found' }) unless menu

      menu.destroy!
      json({ success: true })
    end

    # POST /api/menus/:id/items - Add item to menu
    post '/api/menus/:id/items' do
      require_ajax_header
      require_login

      menu = V7CMS::Menu.find_by(id: params[:id])
      halt 404, json({ error: 'Menu not found' }) unless menu

      data = JSON.parse(request.body.read)
      item = menu.menu_items.build(
        label: data['label'],
        link_type: data['link_type'],
        url: data['url'],
        target: data['target'],
        parent_id: data['parent_id'],
        position: data['position'] || menu.menu_items.maximum(:position).to_i + 1,
        linkable_type: data['linkable_type'],
        linkable_id: data['linkable_id']
      )

      if item.save
        status 201
        json({ item: menu_item_json(item) })
      else
        halt 422, json({ errors: item.errors.full_messages })
      end
    end

    # PUT /api/menu-items/:id - Update menu item
    put '/api/menu-items/:id' do
      require_ajax_header
      require_login

      item = V7CMS::MenuItem.find_by(id: params[:id])
      halt 404, json({ error: 'Menu item not found' }) unless item

      data = JSON.parse(request.body.read)
      updates = {}
      updates[:label] = data['label'] if data.key?('label')
      updates[:url] = data['url'] if data.key?('url')
      updates[:target] = data['target'] if data.key?('target')
      updates[:parent_id] = data['parent_id'] if data.key?('parent_id')
      updates[:position] = data['position'] if data.key?('position')
      updates[:link_type] = data['link_type'] if data.key?('link_type')
      updates[:linkable_type] = data['linkable_type'] if data.key?('linkable_type')
      updates[:linkable_id] = data['linkable_id'] if data.key?('linkable_id')

      if item.update(updates)
        json({ item: menu_item_json(item) })
      else
        halt 422, json({ errors: item.errors.full_messages })
      end
    end

    # DELETE /api/menu-items/:id - Delete menu item
    delete '/api/menu-items/:id' do
      require_ajax_header
      require_login

      item = V7CMS::MenuItem.find_by(id: params[:id])
      halt 404, json({ error: 'Menu item not found' }) unless item

      item.destroy!
      json({ success: true })
    end

    # PUT /api/menus/:id/reorder - Reorder menu items
    put '/api/menus/:id/reorder' do
      require_ajax_header
      require_login

      menu = V7CMS::Menu.find_by(id: params[:id])
      halt 404, json({ error: 'Menu not found' }) unless menu

      data = JSON.parse(request.body.read)
      items = data['items'] || []

      ActiveRecord::Base.transaction do
        items.each do |item_data|
          item = menu.menu_items.find_by(id: item_data['id'])
          next unless item

          item.update!(position: item_data['position'], parent_id: item_data['parent_id'])
        end
      end

      json({ success: true, menu: menu_json(menu, include_items: true) })
    end

    # =========================================================================
    # Redirect Handler (for Docker/Rack deployments without Apache .htaccess)
    # =========================================================================
    # This catch-all route checks for custom redirects stored in the database.
    # For Apache/FastCGI deployments, redirects are handled via .htaccess rules.
    # For Docker/Rack/Puma deployments, this Sinatra handler provides the same
    # functionality by checking the Redirect model before returning a 404.
    # =========================================================================
    not_found do
      # Only check for redirects if we have a path to check
      request_path = request.path_info

      # Look for a matching redirect in the database
      redirect_record = V7CMS::Redirect.find_by(short_path: request_path)

      if redirect_record
        # Perform 301 redirect to target path
        redirect redirect_record.target_path, 301
      elsif body.nil? || body.empty? || (body.is_a?(Array) && body.first.to_s.empty?)
        # Only set default 404 response if the route didn't already set a body
        # (This preserves custom 404 responses from halt 404, json(...))
        if request_path.start_with?('/api/')
          content_type :json
          { error: 'Not found' }.to_json
        else
          # Check for custom error page file (.html, .shtml, .php)
          error_file = self.class.find_error_page(404)
          if error_file
            content_type :html
            File.read(error_file)
          else
            # Fall back to ERB template
            content_type :html
            @settings = V7CMS::Setting.instance
            @title = '404 - Page Not Found'
            erb :'404'
          end
        end
      end
      # If body was already set by the route, just return it as-is
    end

    # =========================================================================
    # Helper Methods
    # =========================================================================

    # JSON helper
    def json(data)
      content_type :json
      data.to_json
    end

    # Post serialization helper
    def post_json(post)
      {
        id: post.id,
        title: post.title,
        slug: post.slug,
        content: post.content,
        published: post.published?,
        status: post.status,
        published_version_id: post.published_version_id,
        has_unpublished_changes: post.has_unpublished_changes?,
        created_at: post.created_at,
        updated_at: post.updated_at,
        comments_enabled: post.comments_enabled,
        comments_allowed: post.comments_allowed?,
        tags: post.tags.map { |t| { id: t.id, name: t.name, slug: t.slug } }
      }
    end

    # Tag serialization helper
    def tag_json(tag)
      {
        id: tag.id,
        name: tag.name,
        slug: tag.slug,
        posts_count: tag.respond_to?(:cached_posts_count) ? tag.cached_posts_count : tag.posts.count
      }
    end

    # Settings serialization helper
    def settings_json(setting)
      {
        site_title: setting.site_title,
        site_tagline: setting.site_tagline,
        site_author: setting.site_author,
        welcome_title: setting.welcome_title,
        welcome_subtitle: setting.welcome_subtitle,
        footer_text: setting.footer_text,
        show_copyright_year: setting.show_copyright_year,
        meta_description: setting.meta_description,
        meta_keywords: setting.meta_keywords,
        contact_email: setting.contact_email,
        github_url: setting.github_url,
        social_url: setting.social_url,
        posts_per_page: setting.posts_per_page,
        date_format: setting.date_format,
        allow_comments: setting.allow_comments,
        reserved_redirect_paths: setting.reserved_redirect_paths,
        layout_homepage: setting.layout_homepage,
        layout_post: setting.layout_post
      }
    end

    # User serialization helper
    def user_json(user)
      {
        id: user.id,
        email: user.email,
        name: user.name,
        provider: user.provider,
        avatar_url: user.avatar_url,
        admin: user.admin,
        created_at: user.created_at,
        last_login_at: user.last_login_at
      }
    end

    # Redirect serialization helper
    def redirect_json(redirect)
      {
        id: redirect.id,
        short_path: redirect.short_path,
        target_path: redirect.target_path,
        created_at: redirect.created_at,
        updated_at: redirect.updated_at
      }
    end

    # Theme serialization helper
    def theme_json(theme)
      # Load theme config
      theme_config_path = File.join(V7CMS.gem_root, 'config', 'theme_fields.rb')
      require theme_config_path if File.exist?(theme_config_path)

      # Build hash from all fields defined in ThemeConfig
      result = { id: theme.id }

      ThemeConfig.field_names.each do |field|
        result[field] = theme.send(field) if theme.respond_to?(field)
      end

      result
    end

    # Page serialization helper
    def page_json(page, include_relations: false)
      result = {
        id: page.id,
        title: page.title,
        slug: page.slug,
        content: page.content,
        published: page.published?,
        status: page.status,
        published_version_id: page.published_version_id,
        has_unpublished_changes: page.has_unpublished_changes?,
        parent_id: page.parent_id,
        position: page.position,
        page_type: page.page_type,
        content_source: page.content_source,
        items_limit: page.items_limit,
        hero_image_url: page.hero_image_url,
        content_filter_tag_id: page.content_filter_tag_id,
        content_filter_tag: page.content_filter_tag ? { id: page.content_filter_tag.id, name: page.content_filter_tag.name, slug: page.content_filter_tag.slug } : nil,
        created_at: page.created_at,
        updated_at: page.updated_at
      }

      if include_relations
        result[:depth] = page.depth
        result[:has_children] = page.has_children?
        result[:parent] = page.parent ? { id: page.parent.id, title: page.parent.title, slug: page.parent.slug } : nil
        result[:children] = page.children.ordered.map { |c| { id: c.id, title: c.title, slug: c.slug, published: c.published? } }
        result[:breadcrumb_trail] = page.breadcrumb_trail.map { |p| { id: p.id, title: p.title, slug: p.slug } }
      end

      result
    end

    # Nested page serialization helper for hierarchical tree view
    def page_json_nested(page, depth, scope)
      base = page_json(page)
      base[:depth] = depth
      base[:children] = page.children.merge(scope).map { |c| page_json_nested(c, depth + 1, scope) }
      base
    end

    # Comment serialization helper
    def comment_json(comment)
      {
        id: comment.id,
        author_name: comment.author_name,
        author_url: comment.author_url,
        content: comment.content,
        created_at: comment.created_at.iso8601,
        post_id: comment.post_id
      }
    end

    # Admin comment serialization helper (includes sensitive fields)
    def admin_comment_json(comment)
      {
        id: comment.id,
        author_name: comment.author_name,
        author_email: comment.author_email,
        author_url: comment.author_url,
        content: comment.content,
        ip_address: comment.ip_address,
        recaptcha_score: comment.recaptcha_score,
        approved: comment.approved,
        spam: comment.spam,
        created_at: comment.created_at.iso8601,
        post: {
          id: comment.post.id,
          title: comment.post.title,
          slug: comment.post.slug
        }
      }
    end

    # Version serialization helper
    def version_json(version, include_content: false)
      result = {
        version_number: version.version_number,
        version_type: version.version_type,
        workflow_state: version.workflow_state,
        title: version.title,
        permanent: version.permanent?,
        expires_at: version.expires_at&.iso8601,
        created_at: version.created_at.iso8601,
        created_by: version.created_by&.name || 'Unknown'
      }
      if include_content
        result[:content] = version.content
        result[:metadata] = version.metadata_hash
      end
      result
    end

    # reCAPTCHA verification helper - supports both Enterprise and Standard v3
    def verify_recaptcha_v3(token, remote_ip)
      return 1.0 if ENV['RACK_ENV'] == 'test' # Bypass in tests

      # Choose Enterprise or Standard based on env vars
      if ENV['RECAPTCHA_PROJECT_ID'] && ENV['RECAPTCHA_API_KEY']
        verify_recaptcha_enterprise(token, remote_ip)
      elsif ENV['RECAPTCHA_SECRET_KEY']
        verify_recaptcha_standard(token, remote_ip)
      else
        puts "reCAPTCHA not configured - skipping verification"
        1.0
      end
    end

    # reCAPTCHA Enterprise verification
    def verify_recaptcha_enterprise(token, remote_ip)
      require 'net/http'
      require 'json'

      project_id = ENV['RECAPTCHA_PROJECT_ID']
      api_key = ENV['RECAPTCHA_API_KEY']
      site_key = ENV['RECAPTCHA_SITE_KEY']

      uri = URI.parse("https://recaptchaenterprise.googleapis.com/v1/projects/#{project_id}/assessments?key=#{api_key}")

      request_body = {
        event: {
          token: token,
          siteKey: site_key,
          expectedAction: 'submit_comment',
          userIpAddress: remote_ip
        }
      }

      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true

      request = Net::HTTP::Post.new(uri.request_uri, { 'Content-Type' => 'application/json' })
      request.body = request_body.to_json

      response = http.request(request)
      result = JSON.parse(response.body)

      # Check token validity and action match
      token_props = result['tokenProperties'] || {}
      risk_analysis = result['riskAnalysis'] || {}

      unless token_props['valid']
        puts "reCAPTCHA Enterprise: invalid token - #{token_props['invalidReason']}"
        return 0.0
      end

      if token_props['action'] != 'submit_comment'
        puts "reCAPTCHA Enterprise: action mismatch - expected submit_comment, got #{token_props['action']}"
        return 0.0
      end

      # Return score (0.0 = bot, 1.0 = human)
      risk_analysis['score'] || 0.0
    rescue => e
      puts "reCAPTCHA Enterprise verification error: #{e.message}"
      0.0
    end

    # Standard reCAPTCHA v3 verification
    def verify_recaptcha_standard(token, remote_ip)
      require 'net/http'
      require 'json'

      uri = URI.parse('https://www.google.com/recaptcha/api/siteverify')
      response = Net::HTTP.post_form(uri, {
        secret: ENV['RECAPTCHA_SECRET_KEY'],
        response: token,
        remoteip: remote_ip
      })

      result = JSON.parse(response.body)

      # Return score (0.0 = bot, 1.0 = human)
      result['success'] ? result['score'] : 0.0
    rescue => e
      puts "reCAPTCHA verification error: #{e.message}"
      0.0
    end

    # Pagination helper - extract and validate pagination parameters
    def pagination_params
      limit = params[:limit].to_i
      offset = params[:offset].to_i

      # Default limit to 20 if not provided or invalid
      limit = 20 if limit <= 0

      # Clamp limit to maximum of 100
      limit = 100 if limit > 100

      # Default offset to 0 if invalid
      offset = 0 if offset < 0

      { limit: limit, offset: offset }
    end

    # Pagination metadata helper - build pagination response object
    def pagination_metadata(total:, limit:, offset:, count:)
      {
        total: total,
        limit: limit,
        offset: offset,
        count: count
      }
    end

    # Theme CSS generation helper using Tailwind v4 @theme directive
    def generate_theme_css(theme = @theme, params_override = params)
      # Load theme config
      theme_config_path = File.join(V7CMS.gem_root, 'config', 'theme_fields.rb')
      require theme_config_path if File.exist?(theme_config_path)

      # Build theme values hash from either params (preview) or model (normal)
      theme_values = if params_override[:theme_preview]
        extract_theme_from_params(params_override, theme)
      else
        extract_theme_from_model(theme)
      end

      # Generate CSS custom properties
      css_lines = ThemeConfig::FIELDS.map do |field, config|
        value = theme_values[field]
        next if value.nil?
        next if config[:css_var].nil? # Skip fields without CSS variables (e.g., header_style, footer_style, custom_css)

        formatted_value = ThemeConfig.format_value(field, value)
        "  #{config[:css_var]}: #{formatted_value};"
      end.compact

      css_lines.join("\n")
    end

    private

    def extract_theme_from_model(theme)
      # Load theme config
      theme_config_path = File.join(V7CMS.gem_root, 'config', 'theme_fields.rb')
      require theme_config_path if File.exist?(theme_config_path)

      # Simple: just get each field value directly from the theme model
      ThemeConfig::FIELDS.each_with_object({}) do |(field, config), hash|
        if theme.respond_to?(field)
          hash[field] = theme.send(field)
        else
          # Use default if field doesn't exist yet (pre-migration)
          hash[field] = config[:default]
        end
      end
    end

    def extract_theme_from_params(params_override, fallback_theme)
      # Load theme config
      theme_config_path = File.join(V7CMS.gem_root, 'config', 'theme_fields.rb')
      require theme_config_path if File.exist?(theme_config_path)

      # Get values from params if present, otherwise fall back to theme model
      ThemeConfig::FIELDS.each_with_object({}) do |(field, config), hash|
        # Try param as string, then symbol, then fall back to theme (with default if field missing)
        param_value = params_override[field.to_s] || params_override[field]
        if param_value
          hash[field] = param_value
        elsif fallback_theme.respond_to?(field)
          hash[field] = fallback_theme.send(field)
        else
          # Use default if field doesn't exist yet (pre-migration)
          hash[field] = config[:default]
        end
      end
    end
  end
end
