# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Users Routes' do
  let(:admin_user) { User.create!(email: 'admin@example.com', name: 'Admin', provider: 'google_oauth2', uid: '12345', admin: true) }
  let(:other_user) { User.create!(email: 'other@example.com', name: 'Other User', provider: 'github', uid: '67890', admin: false) }

  describe 'GET /api/users' do
    context 'when authenticated' do
      it 'returns all users' do
        admin_user
        other_user

        get '/api/users', {}, { 'rack.session' => { user_id: admin_user.id } }

        expect(last_response).to be_ok
        data = JSON.parse(last_response.body)
        expect(data['users']).to be_an(Array)
        expect(data['users'].length).to eq(2)

        emails = data['users'].map { |u| u['email'] }
        expect(emails).to include('admin@example.com', 'other@example.com')
      end

      it 'includes user attributes' do
        admin_user

        get '/api/users', {}, { 'rack.session' => { user_id: admin_user.id } }

        data = JSON.parse(last_response.body)
        user_data = data['users'].first

        expect(user_data).to have_key('id')
        expect(user_data).to have_key('email')
        expect(user_data).to have_key('name')
        expect(user_data).to have_key('provider')
        expect(user_data).to have_key('avatar_url')
        expect(user_data).to have_key('admin')
        expect(user_data).to have_key('created_at')
        expect(user_data).to have_key('last_login_at')
      end

      it 'orders users by created_at descending' do
        admin_user
        sleep(0.1) # Ensure different timestamps
        other_user

        get '/api/users', {}, { 'rack.session' => { user_id: admin_user.id } }

        data = JSON.parse(last_response.body)
        emails = data['users'].map { |u| u['email'] }
        expect(emails).to eq(['other@example.com', 'admin@example.com'])
      end
    end

    context 'when not authenticated' do
      it 'returns 401' do
        get '/api/users'

        expect(last_response.status).to eq(401)
        data = JSON.parse(last_response.body)
        expect(data['error']).to be_a(String)
      end
    end
  end

  describe 'PUT /api/users/:id' do
    context 'when authenticated' do
      it 'updates admin status to true' do
        admin_user
        other_user

        put "/api/users/#{other_user.id}",
            { admin: true }.to_json,
            {
              'rack.session' => { user_id: admin_user.id },
              'CONTENT_TYPE' => 'application/json',
              'HTTP_X_REQUESTED_WITH' => 'XMLHttpRequest'
            }

        expect(last_response).to be_ok
        data = JSON.parse(last_response.body)
        expect(data['user']['admin']).to be true

        other_user.reload
        expect(other_user.admin).to be true
      end

      it 'updates admin status to false' do
        admin_user
        second_admin = User.create!(email: 'admin2@example.com', name: 'Admin 2', provider: 'google_oauth2', uid: '11111', admin: true)

        put "/api/users/#{second_admin.id}",
            { admin: false }.to_json,
            {
              'rack.session' => { user_id: admin_user.id },
              'CONTENT_TYPE' => 'application/json',
              'HTTP_X_REQUESTED_WITH' => 'XMLHttpRequest'
            }

        expect(last_response).to be_ok
        data = JSON.parse(last_response.body)
        expect(data['user']['admin']).to be false

        second_admin.reload
        expect(second_admin.admin).to be false
      end

      it 'rejects revoking own admin access' do
        admin_user

        put "/api/users/#{admin_user.id}",
            { admin: false }.to_json,
            {
              'rack.session' => { user_id: admin_user.id },
              'CONTENT_TYPE' => 'application/json',
              'HTTP_X_REQUESTED_WITH' => 'XMLHttpRequest'
            }

        expect(last_response.status).to eq(400)
        data = JSON.parse(last_response.body)
        expect(data['error']).to include('Cannot revoke your own admin access')

        admin_user.reload
        expect(admin_user.admin).to be true
      end

      it 'allows revoking admin when multiple admins exist' do
        # This tests the happy path: with 2+ admins, one can revoke another
        admin_user
        second_admin = User.create!(email: 'admin2@example.com', name: 'Admin 2', provider: 'google_oauth2', uid: '11111', admin: true)

        put "/api/users/#{second_admin.id}",
            { admin: false }.to_json,
            {
              'rack.session' => { user_id: admin_user.id },
              'CONTENT_TYPE' => 'application/json',
              'HTTP_X_REQUESTED_WITH' => 'XMLHttpRequest'
            }

        expect(last_response).to be_ok
        second_admin.reload
        expect(second_admin.admin).to be false
      end

      it 'returns 404 for unknown user' do
        admin_user

        put '/api/users/999999',
            { admin: true }.to_json,
            {
              'rack.session' => { user_id: admin_user.id },
              'CONTENT_TYPE' => 'application/json',
              'HTTP_X_REQUESTED_WITH' => 'XMLHttpRequest'
            }

        expect(last_response.status).to eq(404)
        data = JSON.parse(last_response.body)
        expect(data['error']).to include('User not found')
      end

      it 'returns 422 for invalid JSON' do
        admin_user

        put "/api/users/#{admin_user.id}",
            'invalid json',
            {
              'rack.session' => { user_id: admin_user.id },
              'CONTENT_TYPE' => 'application/json',
              'HTTP_X_REQUESTED_WITH' => 'XMLHttpRequest'
            }

        expect(last_response.status).to eq(422)
      end
    end

    context 'when not authenticated' do
      it 'returns 401' do
        other_user

        put "/api/users/#{other_user.id}",
            { admin: true }.to_json,
            {
              'CONTENT_TYPE' => 'application/json',
              'HTTP_X_REQUESTED_WITH' => 'XMLHttpRequest'
            }

        expect(last_response.status).to eq(401)
      end
    end

  end
end
