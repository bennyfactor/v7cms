require 'spec_helper'

RSpec.describe 'Basic Routes' do
  # Clear setting cache before each test
  before do
    Setting.clear_cache! if Setting.respond_to?(:clear_cache!)
  end

  describe 'GET /' do
    it 'returns the homepage' do
      get '/'
      expect(last_response).to be_ok
      expect(last_response.content_type).to include('text/html')
      expect(last_response.body).to include('Welcome to v7cms')
    end
  end

  describe 'GET /api' do
    it 'returns API welcome message' do
      get '/api'
      expect(last_response).to be_ok
      expect(last_response.content_type).to include('application/json')

      data = JSON.parse(last_response.body)
      expect(data['message']).to eq('v7cms API - Coming soon')
    end
  end

  describe 'GET /health' do
    it 'returns health status' do
      get '/health'
      expect(last_response).to be_ok

      data = JSON.parse(last_response.body)
      expect(data['status']).to eq('ok')
    end

    it 'returns error status when database connection fails' do
      # Mock the database connection to raise an error
      allow(ActiveRecord::Base).to receive(:connection).and_raise(StandardError.new('Connection failed'))

      get '/health'
      expect(last_response).to be_ok

      data = JSON.parse(last_response.body)
      expect(data['status']).to eq('ok')
      expect(data['database']).to eq('error')
    end
  end

  describe 'GET /posts/:slug' do
    let!(:post) { Post.create!(title: 'Test Post', slug: 'test-post', content: '<p>Test content</p>', published: true) }

    it 'returns the post page' do
      get '/posts/test-post'

      expect(last_response).to be_ok
      expect(last_response.content_type).to include('text/html')
      expect(last_response.body).to include('Test Post')
    end

    it 'returns 404 for non-existent post' do
      get '/posts/non-existent'

      expect(last_response.status).to eq(404)
    end

    it 'returns 404 for unpublished posts' do
      draft = Post.create!(title: 'Draft', slug: 'draft', content: 'Draft', published: false)
      get '/posts/draft'

      expect(last_response.status).to eq(404)
    end

    describe 'post layout rendering' do
      it 'uses standard layout by default' do
        Setting.instance.update!(layout_post: 'standard')

        get '/posts/test-post'

        expect(last_response).to be_ok
        expect(last_response.body).to include('Test Post')
        # Standard layout has card styling with shadow
        expect(last_response.body).to include('shadow-md')
      end

      it 'uses minimal layout when configured' do
        Setting.instance.update!(layout_post: 'minimal')

        get '/posts/test-post'

        expect(last_response).to be_ok
        expect(last_response.body).to include('Test Post')
        # Minimal layout has narrower width and lighter styling
        expect(last_response.body).to include('max-w-2xl')
      end

      it 'falls back to standard layout for invalid setting' do
        # Bypass validation to set invalid value
        Setting.instance.update_column(:layout_post, 'nonexistent')

        get '/posts/test-post'

        expect(last_response).to be_ok
        expect(last_response.body).to include('Test Post')
      end
    end
  end
end
