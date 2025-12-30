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
end
