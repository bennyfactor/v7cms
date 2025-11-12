require 'spec_helper'

RSpec.describe 'Basic Routes' do
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
  end
end
