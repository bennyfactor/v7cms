require_relative '../spec_helper'
require 'rack/attack'

RSpec.describe 'Rate Limiting' do
  include Rack::Test::Methods

  def app
    # Load rate limit config and build test app
    require_relative '../../config/rate_limit'

    Rack::Builder.new do
      use Rack::Attack
      run CMS
    end
  end

  before do
    # Use test cache to avoid pollution between tests
    cache_dir = File.join(File.expand_path('../..', __dir__), 'tmp', 'test-rack-attack-cache')
    Rack::Attack.cache.store = ActiveSupport::Cache::FileStore.new(cache_dir, expires_in: 1.hour)
    Rack::Attack.enabled = true
  end

  after do
    # Clear cache after each test
    Rack::Attack.cache.store.clear
  end

  describe 'general traffic throttle' do
    it 'allows requests under the limit' do
      50.times do
        get '/api/posts'
        expect(last_response.status).not_to eq(429)
      end
    end

    it 'blocks requests over the limit' do
      110.times do |i|
        get '/api/posts'
        if i < 100
          expect(last_response.status).not_to eq(429)
        else
          expect(last_response.status).to eq(429)
        end
      end
    end

    it 'includes Retry-After header when rate limited' do
      110.times { get '/api/posts' }
      expect(last_response.status).to eq(429)
      expect(last_response.headers['Retry-After']).to eq('60')
    end

    it 'does not rate limit admin paths' do
      # Admin paths should bypass rate limiting
      110.times do
        get '/admin/'
        expect(last_response.status).not_to eq(429)
      end
    end
  end

  describe 'API write throttle' do
    it 'allows 20 write requests per minute' do
      20.times do
        post '/api/posts', { title: 'Test' }.to_json, 'CONTENT_TYPE' => 'application/json'
        # May be 401 (unauthorized) but not 429 (rate limited)
        expect(last_response.status).not_to eq(429)
      end
    end

    it 'blocks write requests over limit' do
      25.times do |i|
        post '/api/posts', { title: 'Test' }.to_json, 'CONTENT_TYPE' => 'application/json'
        if i < 20
          # May be 401 (unauthorized) but not 429 (rate limited)
          expect(last_response.status).not_to eq(429)
        else
          expect(last_response.status).to eq(429)
        end
      end
    end

    it 'only rate limits write methods' do
      # GET requests use general throttle (100/min), not write throttle (20/min)
      25.times do
        get '/api/posts'
        expect(last_response.status).not_to eq(429)
      end
    end
  end

  describe 'login throttle' do
    it 'allows 5 login attempts per minute' do
      5.times do
        post '/auth/google_oauth2/callback'
        expect(last_response.status).not_to eq(429)
      end
    end

    it 'blocks login attempts over limit' do
      10.times do |i|
        post '/auth/google_oauth2/callback'
        if i < 5
          expect(last_response.status).not_to eq(429)
        else
          expect(last_response.status).to eq(429)
        end
      end
    end
  end

  describe 'IP blocklist' do
    it 'blocks requests from IPs in BLOCKED_IPS env var' do
      # Set blocked IP
      ENV['BLOCKED_IPS'] = '192.168.1.100,10.0.0.50'

      # Reload Rack::Attack config to pick up env change
      load File.expand_path('../../config/rate_limit.rb', __dir__)

      # Request from blocked IP should be denied
      get '/api/posts', {}, { 'REMOTE_ADDR' => '192.168.1.100' }
      expect(last_response.status).to eq(403)

      # Clean up
      ENV.delete('BLOCKED_IPS')
    end

    it 'allows requests from non-blocked IPs' do
      ENV['BLOCKED_IPS'] = '192.168.1.100'

      # Reload config
      load File.expand_path('../../config/rate_limit.rb', __dir__)

      # Request from different IP should be allowed (not 403)
      get '/api/posts', {}, { 'REMOTE_ADDR' => '10.0.0.1' }
      expect(last_response.status).not_to eq(403)

      # Clean up
      ENV.delete('BLOCKED_IPS')
    end
  end
end
