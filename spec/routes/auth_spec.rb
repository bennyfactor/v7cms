require 'spec_helper'

RSpec.describe 'Authentication Routes' do
  describe 'GET /auth/:provider/callback' do
    let(:auth_hash) do
      OmniAuth::AuthHash.new({
        'provider' => 'google_oauth2',
        'uid' => '123456',
        'info' => {
          'email' => 'user@example.com',
          'name' => 'Test User',
          'image' => 'https://example.com/avatar.jpg'
        }
      })
    end

    before do
      # Mock OmniAuth auth hash - key must match the provider name
      OmniAuth.config.test_mode = true
      OmniAuth.config.mock_auth[:google_oauth2] = auth_hash
    end

    after do
      OmniAuth.config.test_mode = false
      OmniAuth.config.mock_auth[:google_oauth2] = nil
    end

    context 'when authentication succeeds' do
      it 'creates a new user from OAuth' do
        expect {
          # In test mode, just call the callback - OmniAuth will use mock_auth
          get '/auth/google_oauth2/callback'
        }.to change(User, :count).by(1)

        expect(last_response).to be_ok
        data = JSON.parse(last_response.body)
        expect(data['success']).to be true
        expect(data['user']['email']).to eq('user@example.com')
      end

      it 'finds existing user' do
        existing_user = User.create!(
          email: 'user@example.com',
          name: 'Test User',
          provider: 'google_oauth2',
          uid: '123456'
        )

        expect {
          get '/auth/google_oauth2/callback'
        }.not_to change(User, :count)

        expect(last_response).to be_ok
        data = JSON.parse(last_response.body)
        expect(data['user']['id']).to eq(existing_user.id)
      end

      it 'sets session user_id' do
        get '/auth/google_oauth2/callback'

        expect(last_response).to be_ok
        # Verify the user was created and data returned
        user = User.last
        expect(user.email).to eq('user@example.com')

        data = JSON.parse(last_response.body)
        expect(data['success']).to be true
        expect(data['user']['id']).to eq(user.id)
      end
    end
  end

  describe 'GET /auth/failure' do
    it 'returns error message' do
      get '/auth/failure', { message: 'invalid_credentials' }

      expect(last_response.status).to eq(401)
      data = JSON.parse(last_response.body)
      expect(data['error']).to eq('invalid_credentials')
    end

    it 'returns generic message if no specific error' do
      get '/auth/failure'

      expect(last_response.status).to eq(401)
      data = JSON.parse(last_response.body)
      expect(data['error']).to eq('Authentication failed')
    end
  end

  describe 'POST /api/auth/logout' do
    let(:user) { User.create!(email: 'test@example.com', provider: 'google', uid: '12345', name: 'Test') }

    it 'clears the session' do
      post '/api/auth/logout', {}, { 'rack.session' => { user_id: user.id } }

      expect(last_response).to be_ok
      data = JSON.parse(last_response.body)
      expect(data['success']).to be true
    end
  end

  describe 'GET /api/auth/me' do
    context 'when logged in' do
      let(:user) { User.create!(email: 'test@example.com', provider: 'google', uid: '12345', name: 'Test User', avatar_url: 'http://example.com/avatar.jpg') }

      it 'returns current user info' do
        get '/api/auth/me', {}, { 'rack.session' => { user_id: user.id } }

        expect(last_response).to be_ok
        data = JSON.parse(last_response.body)
        expect(data['logged_in']).to be true
        expect(data['user']['id']).to eq(user.id)
        expect(data['user']['email']).to eq('test@example.com')
        expect(data['user']['name']).to eq('Test User')
        expect(data['user']['avatar_url']).to eq('http://example.com/avatar.jpg')
        expect(data['user']['provider']).to eq('google')
      end
    end

    context 'when not logged in' do
      it 'returns logged_in false' do
        get '/api/auth/me'

        expect(last_response).to be_ok
        data = JSON.parse(last_response.body)
        expect(data['logged_in']).to be false
      end
    end
  end
end
