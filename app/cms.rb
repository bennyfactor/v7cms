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

  # Load helpers
  Dir[File.join(__dir__, 'helpers', '*.rb')].each { |file| require file }
  helpers AuthHelper

  # Enable sessions for authentication
  enable :sessions
  set :session_secret, ENV.fetch('SESSION_SECRET', SecureRandom.hex(32))

  # Serve static files from public directory
  set :public_folder, File.expand_path('../public', __dir__)
  set :static, true

  # Fix SCRIPT_NAME for FastCGI - remove /index.fcgi from URLs
  # This middleware strips /index.fcgi from SCRIPT_NAME so OAuth callbacks work correctly
  use(Class.new do
    def initialize(app)
      @app = app
    end

    def call(env)
      # Remove /index.fcgi from SCRIPT_NAME if present
      if env['SCRIPT_NAME'] == '/index.fcgi'
        env['SCRIPT_NAME'] = ''
      end
      @app.call(env)
    end
  end)

  # CSRF protection for OmniAuth (disabled in test)
  # Exclude /auth routes from CSRF protection to allow OAuth flows
  use Rack::Protection, except: [:session_hijacking, :remote_token] unless ENV['RACK_ENV'] == 'test'
  use Rack::Protection::AuthenticityToken, except: ->(env) { env['PATH_INFO'].start_with?('/auth') } unless ENV['RACK_ENV'] == 'test'

  # OmniAuth configuration
  OmniAuth.config.allowed_request_methods = [:get, :post]

  use OmniAuth::Builder do
    # Google OAuth
    provider :google_oauth2,
      ENV['GOOGLE_CLIENT_ID'],
      ENV['GOOGLE_CLIENT_SECRET'],
      {
        scope: 'email,profile',
        prompt: 'select_account',
        image_aspect_ratio: 'square',
        image_size: 256
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
    auth = request.env['omniauth.auth']

    user = User.from_omniauth(auth)

    if user
      session[:user_id] = user.id

      json({
        success: true,
        user: {
          id: user.id,
          email: user.email,
          name: user.name,
          avatar_url: user.avatar_url,
          provider: user.provider
        }
      })
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
    posts = if logged_in? && params[:include_drafts] == 'true'
      Post.recent
    else
      Post.published.recent
    end

    json({ posts: posts.map { |p| post_json(p) } })
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
    require_login

    post = Post.find_by(id: params[:id])

    if post.nil?
      halt 404, json({ error: 'Post not found' })
    end

    post.destroy
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
end
