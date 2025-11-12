require 'spec_helper'

RSpec.describe 'AuthHelper' do
  describe '#current_user' do
    context 'when user is logged in' do
      let(:user) { User.create!(email: 'test@example.com', provider: 'google', uid: '12345', name: 'Test User') }

      it 'returns the current user' do
        get '/api/auth/me', {}, { 'rack.session' => { user_id: user.id } }

        expect(last_response).to be_ok
        data = JSON.parse(last_response.body)
        expect(data['logged_in']).to be true
        expect(data['user']['id']).to eq(user.id)
      end
    end

    context 'when user is not logged in' do
      it 'returns nil' do
        get '/api/auth/me'

        expect(last_response).to be_ok
        data = JSON.parse(last_response.body)
        expect(data['logged_in']).to be false
      end
    end

    context 'when session has invalid user_id' do
      it 'returns nil for non-existent user' do
        get '/api/auth/me', {}, { 'rack.session' => { user_id: 99999 } }

        expect(last_response).to be_ok
        data = JSON.parse(last_response.body)
        expect(data['logged_in']).to be false
      end
    end
  end

  describe '#logged_in?' do
    context 'when user is logged in' do
      let(:user) { User.create!(email: 'test@example.com', provider: 'google', uid: '12345', name: 'Test User') }

      it 'returns true' do
        get '/api/auth/me', {}, { 'rack.session' => { user_id: user.id } }

        expect(last_response).to be_ok
        data = JSON.parse(last_response.body)
        expect(data['logged_in']).to be true
      end
    end

    context 'when user is not logged in' do
      it 'returns false' do
        get '/api/auth/me'

        expect(last_response).to be_ok
        data = JSON.parse(last_response.body)
        expect(data['logged_in']).to be false
      end
    end
  end

  describe '#require_login' do
    # We'll create a test endpoint that uses require_login
    before(:all) do
      CMS.class_eval do
        get '/test/protected' do
          require_login
          json({ message: 'Access granted' })
        end
      end
    end

    context 'when user is logged in' do
      let(:user) { User.create!(email: 'test@example.com', provider: 'google', uid: '12345', name: 'Test User') }

      it 'does not halt' do
        get '/test/protected', {}, { 'rack.session' => { user_id: user.id } }

        expect(last_response).to be_ok
        data = JSON.parse(last_response.body)
        expect(data['message']).to eq('Access granted')
      end
    end

    context 'when user is not logged in' do
      it 'halts with 401 unauthorized' do
        get '/test/protected'

        expect(last_response.status).to eq(401)
        data = JSON.parse(last_response.body)
        expect(data['error']).to eq('Unauthorized')
      end
    end
  end
end
