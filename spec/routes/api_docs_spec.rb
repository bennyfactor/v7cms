# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'API Docs Routes' do
  let(:admin) { User.create!(email: 'admin@example.com', provider: 'google_oauth2', uid: '12345', name: 'Admin', admin: true) }

  def login_as(user)
    { 'rack.session' => { user_id: user.id } }
  end

  describe 'GET /api-docs.html' do
    it 'rejects anonymous requests' do
      get '/api-docs.html'

      expect(last_response.status).to eq(401)
    end

    it 'serves the docs page to a logged-in admin' do
      get '/api-docs.html', {}, login_as(admin)

      expect(last_response).to be_ok
      expect(last_response.content_type).to include('text/html')
      expect(last_response.body).to include('swagger')
    end
  end

  describe 'GET /api-spec.json' do
    it 'rejects anonymous requests' do
      get '/api-spec.json'

      expect(last_response.status).to eq(401)
    end

    it 'serves the OpenAPI spec to a logged-in admin' do
      get '/api-spec.json', {}, login_as(admin)

      expect(last_response).to be_ok
      data = JSON.parse(last_response.body)
      expect(data['openapi'] || data['swagger']).to be_present
    end
  end

  describe 'GET /api/docs' do
    it 'redirects to the docs page' do
      get '/api/docs', {}, login_as(admin)

      expect(last_response.status).to eq(302)
      expect(last_response.location).to end_with('/api-docs.html')
    end
  end
end
