require 'spec_helper'

RSpec.describe 'Theme Routes' do
  let(:user) { User.create!(email: 'admin@example.com', provider: 'google_oauth2', uid: '12345', name: 'Admin') }

  # Mock callbacks to prevent actual file generation during tests
  before do
    allow_any_instance_of(Theme).to receive(:regenerate_theme_css)
    allow_any_instance_of(Theme).to receive(:regenerate_all_static_files)
  end

  describe 'GET /api/theme' do
    it 'returns current theme' do
      get '/api/theme'

      expect(last_response).to be_ok
      data = JSON.parse(last_response.body)
      expect(data['theme']).to be_present
      expect(data['theme']['primary_color']).to eq('#3b82f6')
    end

    it 'works without authentication' do
      get '/api/theme'

      expect(last_response).to be_ok
    end

    it 'includes all theme fields' do
      get '/api/theme'

      data = JSON.parse(last_response.body)
      theme = data['theme']

      # Color fields
      expect(theme).to have_key('primary_color')
      expect(theme).to have_key('secondary_color')
      expect(theme).to have_key('background_color')
      expect(theme).to have_key('text_color')
      expect(theme).to have_key('heading_color')
      expect(theme).to have_key('link_color')
      expect(theme).to have_key('link_hover_color')
      expect(theme).to have_key('border_color')

      # Typography fields
      expect(theme).to have_key('font_heading')
      expect(theme).to have_key('font_body')
      expect(theme).to have_key('font_size_base')
      expect(theme).to have_key('line_height_base')

      # Layout fields
      expect(theme).to have_key('layout_width')
      expect(theme).to have_key('spacing_unit')
      expect(theme).to have_key('radius_default')

      # Advanced fields
      expect(theme).to have_key('custom_css')
    end
  end

  describe 'PUT /api/theme' do
    context 'when not logged in' do
      it 'returns 401 unauthorized' do
        put '/api/theme',
          { primary_color: '#ff0000' }.to_json,
          { 'CONTENT_TYPE' => 'application/json' }

        expect(last_response.status).to eq(401)
      end
    end

    context 'when logged in' do
      it 'updates theme colors' do
        put '/api/theme',
          { primary_color: '#ff0000', secondary_color: '#00ff00' }.to_json,
          { 'rack.session' => { user_id: user.id }, 'CONTENT_TYPE' => 'application/json' }

        expect(last_response).to be_ok
        data = JSON.parse(last_response.body)
        expect(data['theme']['primary_color']).to eq('#ff0000')
        expect(data['theme']['secondary_color']).to eq('#00ff00')

        # Verify database was updated
        theme = Theme.instance.reload
        expect(theme.primary_color).to eq('#ff0000')
        expect(theme.secondary_color).to eq('#00ff00')
      end

      it 'updates typography settings' do
        put '/api/theme',
          { font_size_base: 18, line_height_base: 1.8 }.to_json,
          { 'rack.session' => { user_id: user.id }, 'CONTENT_TYPE' => 'application/json' }

        expect(last_response).to be_ok
        data = JSON.parse(last_response.body)
        expect(data['theme']['font_size_base']).to eq(18)
        # line_height_base is a decimal field, could be serialized as string by JSON
        expect(data['theme']['line_height_base'].to_f).to eq(1.8)
      end

      it 'updates layout settings' do
        put '/api/theme',
          { layout_width: 'wide', radius_default: '16px' }.to_json,
          { 'rack.session' => { user_id: user.id }, 'CONTENT_TYPE' => 'application/json' }

        expect(last_response).to be_ok
        data = JSON.parse(last_response.body)
        expect(data['theme']['layout_width']).to eq('wide')
        expect(theme['radius_default']).to eq('16px')
      end

      it 'updates custom CSS' do
        custom_css = '.custom { color: red; }'
        put '/api/theme',
          { custom_css: custom_css }.to_json,
          { 'rack.session' => { user_id: user.id }, 'CONTENT_TYPE' => 'application/json' }

        expect(last_response).to be_ok
        data = JSON.parse(last_response.body)
        expect(data['theme']['custom_css']).to eq(custom_css)
      end

      it 'returns validation errors for invalid color format' do
        put '/api/theme',
          { primary_color: 'not-a-color' }.to_json,
          { 'rack.session' => { user_id: user.id }, 'CONTENT_TYPE' => 'application/json' }

        expect(last_response.status).to eq(422)
        data = JSON.parse(last_response.body)
        expect(data['errors']).to be_present
        expect(data['errors']).to include('Primary color must be a valid hex color')
      end

      it 'returns validation errors for invalid font size' do
        put '/api/theme',
          { font_size_base: 100 }.to_json,
          { 'rack.session' => { user_id: user.id }, 'CONTENT_TYPE' => 'application/json' }

        expect(last_response.status).to eq(422)
        data = JSON.parse(last_response.body)
        expect(data['errors']).to be_present
      end

      it 'returns validation errors for invalid layout width' do
        put '/api/theme',
          { layout_width: 'invalid' }.to_json,
          { 'rack.session' => { user_id: user.id }, 'CONTENT_TYPE' => 'application/json' }

        expect(last_response.status).to eq(422)
        data = JSON.parse(last_response.body)
        expect(data['errors']).to be_present
      end

      it 'returns 422 for malformed JSON' do
        put '/api/theme',
          'invalid json content',
          { 'rack.session' => { user_id: user.id }, 'CONTENT_TYPE' => 'application/json' }

        expect(last_response.status).to eq(422)
        data = JSON.parse(last_response.body)
        expect(data['errors']).to include('Invalid JSON')
      end

      it 'updates multiple fields at once' do
        put '/api/theme',
          {
            primary_color: '#111111',
            secondary_color: '#222222',
            font_size_base: 18,
            layout_width: 'wide',
            radius_default: '16px'
          }.to_json,
          { 'rack.session' => { user_id: user.id }, 'CONTENT_TYPE' => 'application/json' }

        expect(last_response).to be_ok
        data = JSON.parse(last_response.body)
        expect(data['theme']['primary_color']).to eq('#111111')
        expect(data['theme']['secondary_color']).to eq('#222222')
        expect(data['theme']['font_size_base']).to eq(18)
        expect(data['theme']['layout_width']).to eq('wide')
        expect(data['theme']['radius_default']).to eq('16px')
      end

    end
  end

  describe 'POST /api/theme/reset' do
    context 'when not logged in' do
      it 'returns 401 unauthorized' do
        post '/api/theme/reset', {}, { 'CONTENT_TYPE' => 'application/json' }

        expect(last_response.status).to eq(401)
      end
    end

    context 'when logged in' do
      it 'resets theme to defaults' do
        # First, modify theme
        theme = Theme.instance
        theme.update!(
          primary_color: '#000000',
          secondary_color: '#111111',
          font_size_base: 18,
          layout_width: 'wide'
        )

        # Reset to defaults
        post '/api/theme/reset',
          {},
          { 'rack.session' => { user_id: user.id }, 'CONTENT_TYPE' => 'application/json' }

        expect(last_response).to be_ok
        data = JSON.parse(last_response.body)
        expect(data['theme']['primary_color']).to eq('#3b82f6')
        expect(data['theme']['secondary_color']).to eq('#8b5cf6')
        expect(data['theme']['font_size_base']).to eq(16)
        expect(data['theme']['layout_width']).to eq('standard')

        # Verify database was updated
        theme.reload
        expect(theme.primary_color).to eq('#3b82f6')
        expect(theme.secondary_color).to eq('#8b5cf6')
        expect(theme.font_size_base).to eq(16)
        expect(theme.layout_width).to eq('standard')
      end
    end
  end

  describe 'GET /api/theme/preview' do
    it 'returns CSS content type' do
      get '/api/theme/preview'

      expect(last_response).to be_ok
      expect(last_response.content_type).to include('text/css')
    end

    it 'returns valid CSS' do
      get '/api/theme/preview'

      css = last_response.body
      expect(css).to include(':root {')
      expect(css).to include('--color-primary:')
      expect(css).to include('body {')
    end

    it 'works without authentication' do
      get '/api/theme/preview'

      expect(last_response).to be_ok
    end

    it 'generates CSS based on current theme' do
      theme = Theme.instance
      theme.update!(primary_color: '#abcdef')

      get '/api/theme/preview'

      css = last_response.body
      expect(css).to include('--color-primary: #abcdef;')
    end

    it 'accepts query parameter overrides' do
      get '/api/theme/preview?primary_color=%23ff0000'

      css = last_response.body
      expect(css).to include('--color-primary: #ff0000;')
    end

    it 'does not save overrides to database' do
      original_color = Theme.instance.primary_color

      get '/api/theme/preview?primary_color=%23ff0000'

      expect(last_response).to be_ok
      expect(Theme.instance.reload.primary_color).to eq(original_color)
    end

    it 'generates CSS with multiple parameter overrides' do
      get '/api/theme/preview?primary_color=%23ff0000&font_size_base=18'

      css = last_response.body
      expect(css).to include('--color-primary: #ff0000;')
      expect(css).to include('--font-size-base: 18px;')
    end
  end
end
