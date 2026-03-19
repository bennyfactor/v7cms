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

  describe 'GET / with menu' do
    it 'renders header menu items in the homepage HTML' do
      menu = V7CMS::Menu.create!(name: 'Main', location: 'header')
      menu.menu_items.create!(label: 'About Us', link_type: 'custom', url: '/about', position: 0)
      menu.menu_items.create!(label: 'Contact', link_type: 'custom', url: '/contact', position: 1)

      get '/'
      expect(last_response).to be_ok
      expect(last_response.body).to include('About Us')
      expect(last_response.body).to include('Contact')
      expect(last_response.body).to include('href="/about"')
      expect(last_response.body).to include('href="/contact"')
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
    let!(:post) do
      post = Post.create!(title: 'Test Post', slug: 'test-post', content: '<p>Test content</p>', status: 'draft')
      version = post.content_versions.create!(
        version_number: 1, version_type: 'workflow', workflow_state: 'published',
        title: 'Test Post', content: '<p>Test content</p>'
      )
      post.update_column(:published_version_id, version.id)
      post
    end

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
      draft = Post.create!(title: 'Draft', slug: 'draft', content: 'Draft', status: 'draft')
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

    describe 'serves published version' do
      it 'displays published version content, not working draft' do
        versioned_post = Post.create!(title: 'Draft Title', slug: 'versioned-post', content: '<p>Draft Content</p>', status: 'draft')
        version = versioned_post.content_versions.create!(
          version_number: 1, version_type: 'workflow', workflow_state: 'published',
          title: 'Published Title', content: '<p>Published Content</p>'
        )
        versioned_post.update_column(:published_version_id, version.id)

        get '/posts/versioned-post'

        expect(last_response).to be_ok
        expect(last_response.body).to include('Published Title')
        expect(last_response.body).to include('Published Content')
        expect(last_response.body).not_to include('Draft Title')
        expect(last_response.body).not_to include('Draft Content')
      end

      it 'returns 404 for post without published version' do
        Post.create!(title: 'Draft', slug: 'unpublished-post', content: 'Content', status: 'draft')

        get '/posts/unpublished-post'

        expect(last_response.status).to eq(404)
      end

      it 'shows preview for logged-in admin on unpublished post' do
        user = User.create!(email: 'admin@test.com', name: 'Admin', provider: 'google', uid: '123', admin: true)
        Post.create!(title: 'Draft', slug: 'preview-post', content: '<p>Preview Content</p>', status: 'draft')

        get '/posts/preview-post', nil, { 'rack.session' => { user_id: user.id } }

        expect(last_response).to be_ok
        expect(last_response.body).to include('Preview Content')
        expect(last_response.body).to include('Preview') # Should have preview banner
      end
    end
  end
end
