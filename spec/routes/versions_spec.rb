require 'spec_helper'

RSpec.describe 'Versions API', type: :request do
  include Rack::Test::Methods

  let(:user) { V7CMS::User.create!(email: 'admin@example.com', provider: 'google', uid: '123', admin: true) }
  let(:post_record) { V7CMS::Post.create!(title: 'Test', slug: 'test', content: 'Content') }
  let(:page_record) { V7CMS::Page.create!(title: 'Test Page', slug: 'test-page', content: 'Page Content') }

  def login_as(user)
    env 'rack.session', { user_id: user.id }
  end

  describe 'GET /api/posts/:id/versions' do
    before do
      # Create some versions
      post_record.create_workflow_version!(workflow_state: 'published')
      post_record.create_auto_version!
    end

    it 'requires authentication' do
      get "/api/posts/#{post_record.id}/versions"
      expect(last_response.status).to eq(401)
    end

    it 'returns only permanent versions by default' do
      login_as(user)
      get "/api/posts/#{post_record.id}/versions"

      expect(last_response.status).to eq(200)
      data = JSON.parse(last_response.body)
      expect(data['versions'].length).to eq(1)
      expect(data['versions'][0]['version_type']).to eq('workflow')
    end

    it 'returns all versions when all=true' do
      login_as(user)
      get "/api/posts/#{post_record.id}/versions?all=true"

      expect(last_response.status).to eq(200)
      data = JSON.parse(last_response.body)
      expect(data['versions'].length).to eq(2)
    end

    it 'returns 404 for non-existent post' do
      login_as(user)
      get '/api/posts/999/versions'
      expect(last_response.status).to eq(404)
    end

    it 'includes version metadata' do
      login_as(user)
      get "/api/posts/#{post_record.id}/versions"

      data = JSON.parse(last_response.body)
      version = data['versions'][0]
      expect(version).to have_key('version_number')
      expect(version).to have_key('version_type')
      expect(version).to have_key('title')
      expect(version).to have_key('created_at')
    end
  end

  describe 'GET /api/pages/:id/versions' do
    before do
      page_record.create_workflow_version!(workflow_state: 'published')
    end

    it 'returns versions for page' do
      login_as(user)
      get "/api/pages/#{page_record.id}/versions"

      expect(last_response.status).to eq(200)
      data = JSON.parse(last_response.body)
      expect(data['versions'].length).to eq(1)
    end
  end

  describe 'GET /api/posts/:id/versions/:num' do
    before do
      post_record.create_workflow_version!(workflow_state: 'published')
    end

    it 'requires authentication' do
      get "/api/posts/#{post_record.id}/versions/1"
      expect(last_response.status).to eq(401)
    end

    it 'returns version with content' do
      login_as(user)
      get "/api/posts/#{post_record.id}/versions/1"

      expect(last_response.status).to eq(200)
      data = JSON.parse(last_response.body)
      expect(data['version']['version_number']).to eq(1)
      expect(data['version']['content']).to eq('Content')
      expect(data['version']['metadata']).to be_a(Hash)
    end

    it 'returns 404 for non-existent version' do
      login_as(user)
      get "/api/posts/#{post_record.id}/versions/999"
      expect(last_response.status).to eq(404)
    end
  end

  describe 'GET /api/pages/:id/versions/:num' do
    before do
      page_record.create_workflow_version!(workflow_state: 'published')
    end

    it 'returns version with content' do
      login_as(user)
      get "/api/pages/#{page_record.id}/versions/1"

      expect(last_response.status).to eq(200)
      data = JSON.parse(last_response.body)
      expect(data['version']['content']).to eq('Page Content')
    end
  end

  describe 'POST /api/posts/:id/versions/:num/restore' do
    before do
      post_record.create_workflow_version!(workflow_state: 'published')
      post_record.update!(title: 'Updated Title', content: 'Updated Content')
    end

    it 'requires authentication' do
      post "/api/posts/#{post_record.id}/versions/1/restore",
           '{}',
           { 'CONTENT_TYPE' => 'application/json', 'HTTP_X_REQUESTED_WITH' => 'XMLHttpRequest' }
      expect(last_response.status).to eq(401)
    end

    it 'restores post to version' do
      login_as(user)
      post "/api/posts/#{post_record.id}/versions/1/restore",
           '{}',
           { 'CONTENT_TYPE' => 'application/json', 'HTTP_X_REQUESTED_WITH' => 'XMLHttpRequest' }

      expect(last_response.status).to eq(200)
      post_record.reload
      expect(post_record.title).to eq('Test')
      expect(post_record.content).to eq('Content')
    end

    it 'returns the updated post' do
      login_as(user)
      post "/api/posts/#{post_record.id}/versions/1/restore",
           '{}',
           { 'CONTENT_TYPE' => 'application/json', 'HTTP_X_REQUESTED_WITH' => 'XMLHttpRequest' }

      data = JSON.parse(last_response.body)
      expect(data['post']['title']).to eq('Test')
    end

    it 'returns 404 for non-existent version' do
      login_as(user)
      post "/api/posts/#{post_record.id}/versions/999/restore",
           '{}',
           { 'CONTENT_TYPE' => 'application/json', 'HTTP_X_REQUESTED_WITH' => 'XMLHttpRequest' }

      expect(last_response.status).to eq(404)
    end
  end

  describe 'POST /api/pages/:id/versions/:num/restore' do
    before do
      page_record.create_workflow_version!(workflow_state: 'published')
      page_record.update!(title: 'Updated Page')
    end

    it 'restores page to version' do
      login_as(user)
      post "/api/pages/#{page_record.id}/versions/1/restore",
           '{}',
           { 'CONTENT_TYPE' => 'application/json', 'HTTP_X_REQUESTED_WITH' => 'XMLHttpRequest' }

      expect(last_response.status).to eq(200)
      page_record.reload
      expect(page_record.title).to eq('Test Page')
    end
  end

  describe 'POST /api/posts/:id/versions/:num/keep' do
    before do
      post_record.create_auto_version!
    end

    it 'requires authentication' do
      post "/api/posts/#{post_record.id}/versions/1/keep",
           '{}',
           { 'CONTENT_TYPE' => 'application/json', 'HTTP_X_REQUESTED_WITH' => 'XMLHttpRequest' }
      expect(last_response.status).to eq(401)
    end

    it 'marks temporary version as permanent' do
      login_as(user)
      post "/api/posts/#{post_record.id}/versions/1/keep",
           '{}',
           { 'CONTENT_TYPE' => 'application/json', 'HTTP_X_REQUESTED_WITH' => 'XMLHttpRequest' }

      expect(last_response.status).to eq(200)

      version = post_record.version_at(1)
      expect(version.version_type).to eq('manual')
      expect(version.expires_at).to be_nil
    end

    it 'returns updated version' do
      login_as(user)
      post "/api/posts/#{post_record.id}/versions/1/keep",
           '{}',
           { 'CONTENT_TYPE' => 'application/json', 'HTTP_X_REQUESTED_WITH' => 'XMLHttpRequest' }

      data = JSON.parse(last_response.body)
      expect(data['version']['permanent']).to be true
      expect(data['version']['version_type']).to eq('manual')
    end
  end

  describe 'POST /api/pages/:id/versions/:num/keep' do
    before do
      page_record.create_auto_version!
    end

    it 'marks page version as permanent' do
      login_as(user)
      post "/api/pages/#{page_record.id}/versions/1/keep",
           '{}',
           { 'CONTENT_TYPE' => 'application/json', 'HTTP_X_REQUESTED_WITH' => 'XMLHttpRequest' }

      expect(last_response.status).to eq(200)
      expect(page_record.version_at(1).permanent?).to be true
    end
  end
end
