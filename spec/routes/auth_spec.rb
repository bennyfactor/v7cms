require 'spec_helper'

RSpec.describe 'Authentication Routes' do
  describe 'GET /auth/:provider/callback' do
    let(:auth_hash) {
      {
        'provider' => 'google_oauth2',
        'uid' => '12345',
        'info' => {
          'email' => 'test@example.com',
          'name' => 'Test User',
          'image' => 'http://example.com/avatar.jpg'
        }
      }
    }

    before do
      OmniAuth.config.test_mode = true
      OmniAuth.config.mock_auth[:google_oauth2] = OmniAuth::AuthHash.new(auth_hash)
    end

    context 'when ADMIN_EMAILS is not set' do
      it 'rejects all login attempts' do
        allow(ENV).to receive(:[]).and_call_original
        allow(ENV).to receive(:[]).with('ADMIN_EMAILS').and_return(nil)

        get '/auth/google_oauth2/callback'

        expect(last_response.status).to eq(403)
        json = JSON.parse(last_response.body)
        expect(json['error']).to include('Admin access not configured')
      end
    end

    context 'when ADMIN_EMAILS is empty string' do
      it 'rejects all login attempts' do
        allow(ENV).to receive(:[]).and_call_original
        allow(ENV).to receive(:[]).with('ADMIN_EMAILS').and_return('')

        get '/auth/google_oauth2/callback'

        expect(last_response.status).to eq(403)
      end
    end

    context 'when email is in ADMIN_EMAILS whitelist' do
      it 'creates user with admin=true and allows login' do
        allow(ENV).to receive(:[]).and_call_original
        allow(ENV).to receive(:[]).with('ADMIN_EMAILS').and_return('test@example.com,other@example.com')

        expect {
          get '/auth/google_oauth2/callback'
        }.to change(User, :count).by(1)

        expect(last_response.status).to eq(302)
        expect(last_response.location).to include('/admin/')

        user = User.last
        expect(user.email).to eq('test@example.com')
        expect(user.admin).to be true
      end
    end

    context 'when email is NOT in ADMIN_EMAILS whitelist' do
      it 'rejects login attempt with 403' do
        allow(ENV).to receive(:[]).and_call_original
        allow(ENV).to receive(:[]).with('ADMIN_EMAILS').and_return('admin@example.com')

        expect {
          get '/auth/google_oauth2/callback'
        }.not_to change(User, :count)

        expect(last_response.status).to eq(403)
        json = JSON.parse(last_response.body)
        expect(json['error']).to include('not authorized')
      end
    end

    context 'when email has whitespace in ADMIN_EMAILS' do
      it 'handles whitespace correctly' do
        allow(ENV).to receive(:[]).and_call_original
        allow(ENV).to receive(:[]).with('ADMIN_EMAILS').and_return('  test@example.com  ,  other@example.com  ')

        get '/auth/google_oauth2/callback'

        expect(last_response.status).to eq(302)
        user = User.last
        expect(user.admin).to be true
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
    let(:user) { User.create!(email: 'test@example.com', provider: 'google', uid: '12345', name: 'Test', admin: true) }

    it 'clears the session' do
      post '/api/auth/logout', {}, { 'rack.session' => { user_id: user.id } }

      expect(last_response).to be_ok
      data = JSON.parse(last_response.body)
      expect(data['success']).to be true
    end
  end

  describe 'GET /api/auth/me' do
    context 'when logged in' do
      let(:user) { User.create!(email: 'test@example.com', provider: 'google', uid: '12345', name: 'Test User', avatar_url: 'http://example.com/avatar.jpg', admin: true) }

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
