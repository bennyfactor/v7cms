require 'spec_helper'

RSpec.describe 'Redirects API', type: :request do
  let(:user) { User.create!(email: 'admin@example.com', provider: 'google_oauth2', uid: '12345', admin: true) }

  before do
    # Mock HtaccessGenerator to avoid file system operations during tests
    allow(HtaccessGenerator).to receive(:generate).and_return(true)
  end

  describe 'GET /api/redirects' do
    context 'when authenticated' do
      before do
        # Simulate logged-in user
        post '/api/auth/login_for_test', {}, { 'rack.session' => { user_id: user.id } }
      end

      it 'returns list of redirects' do
        Redirect.create!(short_path: '/test1', target_path: '/posts/test1')
        Redirect.create!(short_path: '/test2', target_path: '/posts/test2')

        get '/api/redirects', {}, { 'rack.session' => { user_id: user.id }, 'HTTP_X_REQUESTED_WITH' => 'XMLHttpRequest' }

        expect(last_response.status).to eq(200)
        data = JSON.parse(last_response.body)
        expect(data['redirects']).to be_an(Array)
        expect(data['redirects'].length).to eq(2)
      end

      it 'returns redirects ordered by short_path' do
        Redirect.create!(short_path: '/zzz', target_path: '/posts/zzz')
        Redirect.create!(short_path: '/aaa', target_path: '/posts/aaa')

        get '/api/redirects', {}, { 'rack.session' => { user_id: user.id }, 'HTTP_X_REQUESTED_WITH' => 'XMLHttpRequest' }

        data = JSON.parse(last_response.body)
        expect(data['redirects'][0]['short_path']).to eq('/aaa')
        expect(data['redirects'][1]['short_path']).to eq('/zzz')
      end

      it 'returns empty array when no redirects exist' do
        get '/api/redirects', {}, { 'rack.session' => { user_id: user.id }, 'HTTP_X_REQUESTED_WITH' => 'XMLHttpRequest' }

        data = JSON.parse(last_response.body)
        expect(data['redirects']).to eq([])
      end
    end

    context 'when not authenticated' do
      it 'returns 401 unauthorized' do
        get '/api/redirects', {}, { 'HTTP_X_REQUESTED_WITH' => 'XMLHttpRequest' }
        expect(last_response.status).to eq(401)
      end
    end
  end

  describe 'POST /api/redirects' do
    context 'when authenticated' do
      it 'creates a new redirect' do
        expect {
          post '/api/redirects',
               { short_path: '/test', target_path: '/posts/test' }.to_json,
               { 'rack.session' => { user_id: user.id },
                 'HTTP_X_REQUESTED_WITH' => 'XMLHttpRequest',
                 'CONTENT_TYPE' => 'application/json' }
        }.to change(Redirect, :count).by(1)

        expect(last_response.status).to eq(200)
        data = JSON.parse(last_response.body)
        expect(data['redirect']['short_path']).to eq('/test')
        expect(data['redirect']['target_path']).to eq('/posts/test')
      end

      it 'normalizes paths before saving' do
        post '/api/redirects',
             { short_path: 'test', target_path: 'posts/test' }.to_json,
             { 'rack.session' => { user_id: user.id },
               'HTTP_X_REQUESTED_WITH' => 'XMLHttpRequest',
               'CONTENT_TYPE' => 'application/json' }

        data = JSON.parse(last_response.body)
        expect(data['redirect']['short_path']).to eq('/test')
        expect(data['redirect']['target_path']).to eq('/posts/test')
      end

      it 'returns 422 for invalid data' do
        post '/api/redirects',
             { short_path: '', target_path: '/posts/test' }.to_json,
             { 'rack.session' => { user_id: user.id },
               'HTTP_X_REQUESTED_WITH' => 'XMLHttpRequest',
               'CONTENT_TYPE' => 'application/json' }

        expect(last_response.status).to eq(422)
        data = JSON.parse(last_response.body)
        expect(data['errors']).to be_an(Array)
      end

      it 'returns 422 for reserved paths' do
        post '/api/redirects',
             { short_path: '/admin', target_path: '/posts/test' }.to_json,
             { 'rack.session' => { user_id: user.id },
               'HTTP_X_REQUESTED_WITH' => 'XMLHttpRequest',
               'CONTENT_TYPE' => 'application/json' }

        expect(last_response.status).to eq(422)
        data = JSON.parse(last_response.body)
        expect(data['errors']).to include(match(/conflicts with reserved path/))
      end
    end

    context 'when not authenticated' do
      it 'returns 401 unauthorized' do
        post '/api/redirects',
             { short_path: '/test', target_path: '/posts/test' }.to_json,
             { 'HTTP_X_REQUESTED_WITH' => 'XMLHttpRequest',
               'CONTENT_TYPE' => 'application/json' }

        expect(last_response.status).to eq(401)
      end
    end
  end

  describe 'PUT /api/redirects/:id' do
    let!(:redirect) { Redirect.create!(short_path: '/test', target_path: '/posts/test') }

    context 'when authenticated' do
      it 'updates an existing redirect' do
        put "/api/redirects/#{redirect.id}",
            { short_path: '/updated', target_path: '/posts/updated' }.to_json,
            { 'rack.session' => { user_id: user.id },
              'HTTP_X_REQUESTED_WITH' => 'XMLHttpRequest',
              'CONTENT_TYPE' => 'application/json' }

        expect(last_response.status).to eq(200)
        redirect.reload
        expect(redirect.short_path).to eq('/updated')
        expect(redirect.target_path).to eq('/posts/updated')
      end

      it 'returns 404 for non-existent redirect' do
        put '/api/redirects/99999',
            { short_path: '/updated', target_path: '/posts/updated' }.to_json,
            { 'rack.session' => { user_id: user.id },
              'HTTP_X_REQUESTED_WITH' => 'XMLHttpRequest',
              'CONTENT_TYPE' => 'application/json' }

        expect(last_response.status).to eq(404)
      end

      it 'returns 422 for invalid data' do
        put "/api/redirects/#{redirect.id}",
            { short_path: '/admin', target_path: '/posts/test' }.to_json,
            { 'rack.session' => { user_id: user.id },
              'HTTP_X_REQUESTED_WITH' => 'XMLHttpRequest',
              'CONTENT_TYPE' => 'application/json' }

        expect(last_response.status).to eq(422)
      end
    end

    context 'when not authenticated' do
      it 'returns 401 unauthorized' do
        put "/api/redirects/#{redirect.id}",
            { short_path: '/updated', target_path: '/posts/updated' }.to_json,
            { 'HTTP_X_REQUESTED_WITH' => 'XMLHttpRequest',
              'CONTENT_TYPE' => 'application/json' }

        expect(last_response.status).to eq(401)
      end
    end
  end

  describe 'DELETE /api/redirects/:id' do
    let!(:redirect) { Redirect.create!(short_path: '/test', target_path: '/posts/test') }

    context 'when authenticated' do
      it 'deletes an existing redirect' do
        expect {
          delete "/api/redirects/#{redirect.id}",
                 {},
                 { 'rack.session' => { user_id: user.id },
                   'HTTP_X_REQUESTED_WITH' => 'XMLHttpRequest' }
        }.to change(Redirect, :count).by(-1)

        expect(last_response.status).to eq(200)
        data = JSON.parse(last_response.body)
        expect(data['success']).to be true
      end

      it 'returns 404 for non-existent redirect' do
        delete '/api/redirects/99999',
               {},
               { 'rack.session' => { user_id: user.id },
                 'HTTP_X_REQUESTED_WITH' => 'XMLHttpRequest' }

        expect(last_response.status).to eq(404)
      end
    end

    context 'when not authenticated' do
      it 'returns 401 unauthorized' do
        delete "/api/redirects/#{redirect.id}",
               {},
               { 'HTTP_X_REQUESTED_WITH' => 'XMLHttpRequest' }

        expect(last_response.status).to eq(401)
      end
    end
  end
end
