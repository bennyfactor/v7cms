require 'spec_helper'

RSpec.describe 'Settings Routes' do
  let(:user) { User.create!(email: 'admin@example.com', provider: 'google_oauth2', uid: '12345', name: 'Admin') }

  describe 'GET /api/settings' do
    it 'returns current settings' do
      get '/api/settings'

      expect(last_response).to be_ok
      data = JSON.parse(last_response.body)
      expect(data['settings']).to be_present
      expect(data['settings']['site_title']).to eq('v7cms')
    end

    it 'works without authentication' do
      get '/api/settings'

      expect(last_response).to be_ok
    end

    it 'includes all settings fields' do
      get '/api/settings'

      data = JSON.parse(last_response.body)
      settings = data['settings']

      expect(settings).to have_key('site_title')
      expect(settings).to have_key('site_tagline')
      expect(settings).to have_key('site_author')
      expect(settings).to have_key('welcome_title')
      expect(settings).to have_key('welcome_subtitle')
      expect(settings).to have_key('footer_text')
      expect(settings).to have_key('show_copyright_year')
      expect(settings).to have_key('meta_description')
      expect(settings).to have_key('meta_keywords')
      expect(settings).to have_key('contact_email')
      expect(settings).to have_key('github_url')
      expect(settings).to have_key('social_url')
      expect(settings).to have_key('posts_per_page')
      expect(settings).to have_key('date_format')
    end

    it 'includes allow_comments in response' do
      Setting.instance.update!(allow_comments: false)
      get '/api/settings'
      json = JSON.parse(last_response.body)
      expect(json['settings']['allow_comments']).to eq(false)
    end
  end

  describe 'PUT /api/settings' do
    context 'when not logged in' do
      it 'returns 401 unauthorized' do
        put '/api/settings',
          { site_title: 'New Title' }.to_json,
          { 'CONTENT_TYPE' => 'application/json' }

        expect(last_response.status).to eq(401)
      end
    end

    context 'when logged in' do
      it 'updates settings' do
        put '/api/settings',
          { site_title: 'My Custom CMS', footer_text: 'Custom Footer' }.to_json,
          { 'rack.session' => { user_id: user.id }, 'CONTENT_TYPE' => 'application/json' }

        expect(last_response).to be_ok
        data = JSON.parse(last_response.body)
        expect(data['settings']['site_title']).to eq('My Custom CMS')
        expect(data['settings']['footer_text']).to eq('Custom Footer')

        # Verify database was updated
        settings = Setting.instance.reload
        expect(settings.site_title).to eq('My Custom CMS')
        expect(settings.footer_text).to eq('Custom Footer')
      end

      it 'returns validation errors for invalid data' do
        put '/api/settings',
          { site_title: '' }.to_json,
          { 'rack.session' => { user_id: user.id }, 'CONTENT_TYPE' => 'application/json' }

        expect(last_response.status).to eq(422)
        data = JSON.parse(last_response.body)
        expect(data['errors']).to be_present
      end

      it 'returns 422 for malformed JSON' do
        put '/api/settings',
          'invalid json content',
          { 'rack.session' => { user_id: user.id }, 'CONTENT_TYPE' => 'application/json' }

        expect(last_response.status).to eq(422)
        data = JSON.parse(last_response.body)
        expect(data['errors']).to include('Invalid JSON')
      end

      it 'validates email format' do
        put '/api/settings',
          { contact_email: 'invalid-email' }.to_json,
          { 'rack.session' => { user_id: user.id }, 'CONTENT_TYPE' => 'application/json' }

        expect(last_response.status).to eq(422)
        data = JSON.parse(last_response.body)
        expect(data['errors']).to be_present
      end

      it 'validates URL format' do
        put '/api/settings',
          { github_url: 'not a url' }.to_json,
          { 'rack.session' => { user_id: user.id }, 'CONTENT_TYPE' => 'application/json' }

        expect(last_response.status).to eq(422)
        data = JSON.parse(last_response.body)
        expect(data['errors']).to be_present
      end

      it 'updates multiple fields at once' do
        put '/api/settings',
          {
            site_title: 'My Blog',
            welcome_title: 'Welcome to My Blog',
            footer_text: 'Copyright My Blog',
            posts_per_page: 20
          }.to_json,
          { 'rack.session' => { user_id: user.id }, 'CONTENT_TYPE' => 'application/json' }

        expect(last_response).to be_ok
        data = JSON.parse(last_response.body)
        expect(data['settings']['site_title']).to eq('My Blog')
        expect(data['settings']['welcome_title']).to eq('Welcome to My Blog')
        expect(data['settings']['footer_text']).to eq('Copyright My Blog')
        expect(data['settings']['posts_per_page']).to eq(20)
      end

      it 'updates allow_comments' do
        put '/api/settings', {
          allow_comments: false
        }.to_json, { 'rack.session' => { user_id: user.id }, 'CONTENT_TYPE' => 'application/json' }

        expect(last_response.status).to eq(200)
        expect(Setting.instance.allow_comments).to eq(false)
      end
    end
  end

  describe 'POST /api/settings/reset' do
    context 'when not logged in' do
      it 'returns 401 unauthorized' do
        post '/api/settings/reset', {}, { 'CONTENT_TYPE' => 'application/json' }

        expect(last_response.status).to eq(401)
      end
    end

    context 'when logged in' do
      it 'resets settings to defaults' do
        # First, modify settings
        settings = Setting.instance
        settings.update!(
          site_title: 'Custom Title',
          welcome_title: 'Custom Welcome',
          posts_per_page: 50
        )

        # Reset to defaults
        post '/api/settings/reset',
          {},
          { 'rack.session' => { user_id: user.id }, 'CONTENT_TYPE' => 'application/json' }

        expect(last_response).to be_ok
        data = JSON.parse(last_response.body)
        expect(data['settings']['site_title']).to eq('v7cms')
        expect(data['settings']['welcome_title']).to eq('Welcome to v7cms')
        expect(data['settings']['posts_per_page']).to eq(10)

        # Verify database was updated
        settings.reload
        expect(settings.site_title).to eq('v7cms')
        expect(settings.welcome_title).to eq('Welcome to v7cms')
        expect(settings.posts_per_page).to eq(10)
      end
    end
  end
end
