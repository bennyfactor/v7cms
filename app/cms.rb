require 'sinatra/base'
require 'sinatra/activerecord'
require 'json'
require 'securerandom'
require 'omniauth'
require 'omniauth-google-oauth2'
require 'omniauth-github'

class CMS < Sinatra::Base
  # Register Sinatra::ActiveRecord if available (not in test model-only context)
  register Sinatra::ActiveRecord if defined?(Sinatra::ActiveRecord)

  # Database configuration - load from YAML
  set :database_file, File.expand_path('../config/database.yml', __dir__)

  # Load models
  Dir[File.join(__dir__, 'models', '*.rb')].each { |file| require file }

  # Load services
  Dir[File.join(__dir__, 'services', '*.rb')].each { |file| require file }

  # Load helpers
  Dir[File.join(__dir__, 'helpers', '*.rb')].each { |file| require file }
  helpers AuthHelper

  # Enable sessions for authentication
  enable :sessions
  set :session_secret, ENV.fetch('SESSION_SECRET', SecureRandom.hex(32))
  # Use simple session config - SameSite/Secure might be breaking session persistence
  set :sessions, true unless ENV['RACK_ENV'] == 'test'

  # Serve static files from public directory
  set :public_folder, File.expand_path('../public', __dir__)
  set :static, true

  # CSRF protection (disabled in test)
  # Disable AuthenticityToken entirely - using session-based auth instead
  use Rack::Protection, except: [:session_hijacking, :remote_token, :authenticity_token] unless ENV['RACK_ENV'] == 'test'

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

  # Public site routes

  # Homepage - list all published posts
  get '/' do
    @posts = Post.published.recent
    @title = 'v7cms'
    erb :index
  end

  # View a single post by slug
  get '/posts/:slug' do
    @post = Post.published.find_by(slug: params[:slug])

    if @post.nil?
      status 404
      @title = '404 - Page Not Found'
      return erb :'404'
    end

    @title = @post.title
    @description = @post.content.to_s.gsub(/<[^>]*>/, '')[0..150]
    erb :post
  end

  # View a page by slug (supports hierarchical paths like /parent/child)
  get '/pages/*' do
    slug_path = params[:splat].first

    # Try to find page by exact slug match first
    @page = Page.published.find_by(slug: slug_path)

    # If not found, try matching the last segment (for hierarchical URLs)
    if @page.nil?
      slug = slug_path.split('/').last
      @page = Page.published.find_by(slug: slug)
    end

    if @page.nil?
      status 404
      @title = '404 - Page Not Found'
      return erb :'404'
    end

    @title = @page.title
    @description = @page.content.to_s.gsub(/<[^>]*>/, '')[0..150]
    erb :page
  end

  # RSS Feed - generate dynamically at /feed/rss
  get '/feed/rss' do
    content_type 'application/rss+xml', charset: 'utf-8'
    base_url = "#{request.scheme}://#{request.host_with_port}"
    FeedGenerator.new(base_url: base_url).generate_rss
  end

  # Atom Feed - generate dynamically at /feed/atom
  get '/feed/atom' do
    content_type 'application/atom+xml', charset: 'utf-8'
    base_url = "#{request.scheme}://#{request.host_with_port}"
    FeedGenerator.new(base_url: base_url).generate_atom
  end

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

  # OAuth callback (Google, GitHub, etc. all use this)
  get '/auth/:provider/callback' do
    # Debug logging
    logger.info "OAuth callback received: provider=#{params[:provider]}, path=#{request.path_info}"

    auth = request.env['omniauth.auth']
    logger.info "OmniAuth data: #{auth.inspect}"

    user = User.from_omniauth(auth)
    logger.info "User created/found: #{user.inspect}"

    if user
      session[:user_id] = user.id
      logger.info "Session set: user_id=#{session[:user_id]}"
      # Redirect back to admin page after successful login
      redirect '/admin/'
    else
      logger.error "User creation failed"
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
          provider: current_user.provider
        }
      })
    else
      json({ logged_in: false })
    end
  end

  # Posts API Routes

  # GET /api/posts - List posts
  get '/api/posts' do
    # Apply filters
    posts_scope = if logged_in? && params[:include_drafts] == 'true'
      Post.recent
    else
      Post.published.recent
    end

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
    post = Post.find_by(id: params[:id]) || Post.find_by(slug: params[:id])

    if post.nil?
      halt 404, json({ error: 'Post not found' })
    end

    # Only allow viewing unpublished posts if logged in
    if !post.published && !logged_in?
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

    post = Post.new(
      title: data['title'],
      slug: data['slug'],
      content: data['content'],
      published: data['published'] || false
    )

    if post.save
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

    post = Post.find_by(id: params[:id])

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
    post.published = data['published'] if data.key?('published')

    if post.save
      json({ post: post_json(post) })
    else
      halt 422, json({ errors: post.errors.full_messages })
    end
  end

  # DELETE /api/posts/:id - Delete a post
  delete '/api/posts/:id' do
    require_ajax_header
    require_login

    post = Post.find_by(id: params[:id])

    if post.nil?
      halt 404, json({ error: 'Post not found' })
    end

    post.destroy
    status 204
  end

  # Settings API Routes

  # GET /api/settings - Get current settings (no auth required for public display)
  get '/api/settings' do
    settings = Setting.instance
    json({ settings: settings_json(settings) })
  end

  # PUT /api/settings - Update settings (auth required)
  put '/api/settings' do
    require_ajax_header
    require_login

    settings = Setting.instance

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

    settings = Setting.instance
    settings.reset_to_defaults!

    json({ settings: settings_json(settings) })
  end

  # Pages API Routes

  # GET /api/pages - List pages
  get '/api/pages' do
    pages = if logged_in? && params[:include_drafts] == 'true'
      Page.ordered
    else
      Page.published.ordered
    end

    # Support parent filtering
    pages = pages.where(parent_id: params[:parent_id]) if params[:parent_id]
    pages = pages.top_level if params[:top_level] == 'true'

    json({ pages: pages.map { |p| page_json(p) } })
  end

  # GET /api/pages/:id - Get a single page by ID or slug
  get '/api/pages/:id' do
    page = Page.find_by(id: params[:id]) || Page.find_by(slug: params[:id])

    if page.nil?
      halt 404, json({ error: 'Page not found' })
    end

    # Only allow viewing unpublished pages if logged in
    if !page.published && !logged_in?
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

    page = Page.new(
      title: data['title'],
      slug: data['slug'],
      content: data['content'],
      published: data['published'] || false,
      parent_id: data['parent_id'],
      position: data['position'] || 0,
      page_type: data['page_type'] || 'standard'
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

    page = Page.find_by(id: params[:id])

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
    page.published = data['published'] if data.key?('published')
    page.parent_id = data['parent_id'] if data.key?('parent_id')
    page.position = data['position'] if data.key?('position')
    page.page_type = data['page_type'] if data.key?('page_type')

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

    page = Page.find_by(id: params[:id])

    if page.nil?
      halt 404, json({ error: 'Page not found' })
    end

    page.destroy
    status 204
  end

  # Helper methods

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
      published: post.published,
      created_at: post.created_at,
      updated_at: post.updated_at
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
      date_format: setting.date_format
    }
  end

  # Page serialization helper
  def page_json(page, include_relations: false)
    result = {
      id: page.id,
      title: page.title,
      slug: page.slug,
      content: page.content,
      published: page.published,
      parent_id: page.parent_id,
      position: page.position,
      page_type: page.page_type,
      created_at: page.created_at,
      updated_at: page.updated_at
    }

    if include_relations
      result[:depth] = page.depth
      result[:has_children] = page.has_children?
      result[:parent] = page.parent ? { id: page.parent.id, title: page.parent.title, slug: page.parent.slug } : nil
      result[:children] = page.children.ordered.map { |c| { id: c.id, title: c.title, slug: c.slug, published: c.published } }
      result[:breadcrumb_trail] = page.breadcrumb_trail.map { |p| { id: p.id, title: p.title, slug: p.slug } }
    end

    result
  end
end
