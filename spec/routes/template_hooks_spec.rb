require 'spec_helper'

RSpec.describe 'Template Hook Partials' do
  describe 'default behavior (empty partials)' do
    it 'renders the homepage without extra content from hook partials' do
      get '/'
      expect(last_response).to be_ok

      body = last_response.body
      # Layout renders cleanly — closing tags are present and uninterrupted
      expect(body).to include('</head>')
      expect(body).to include('</body>')
      # No stray hook content appears
      expect(body).not_to include('CUSTOM_HEAD_HOOK')
      expect(body).not_to include('CUSTOM_BODY_HOOK')
    end
  end

  describe 'client override of _head_custom.erb' do
    around do |example|
      # Create a temporary views directory with a custom override
      override_dir = Dir.mktmpdir('v7cms_test_views')
      partials_dir = File.join(override_dir, 'partials')
      FileUtils.mkdir_p(partials_dir)
      File.write(File.join(partials_dir, '_head_custom.erb'), '<meta name="custom-test" content="injected-via-hook">')

      # Prepend our override path so it takes priority
      original_paths = app.settings.views_paths.dup
      app.settings.set :views_paths, [override_dir] + original_paths
      app.settings.set :views, override_dir

      example.run
    ensure
      app.settings.set :views_paths, original_paths
      app.settings.set :views, original_paths.first
      FileUtils.remove_entry(override_dir)
    end

    it 'injects custom meta tags into <head>' do
      get '/'
      expect(last_response).to be_ok
      expect(last_response.body).to include('<meta name="custom-test" content="injected-via-hook">')
    end
  end

  describe 'client override of _body_scripts_custom.erb' do
    around do |example|
      override_dir = Dir.mktmpdir('v7cms_test_views')
      partials_dir = File.join(override_dir, 'partials')
      FileUtils.mkdir_p(partials_dir)
      File.write(File.join(partials_dir, '_body_scripts_custom.erb'), '<script src="/js/custom-analytics.js"></script>')

      original_paths = app.settings.views_paths.dup
      app.settings.set :views_paths, [override_dir] + original_paths
      app.settings.set :views, override_dir

      example.run
    ensure
      app.settings.set :views_paths, original_paths
      app.settings.set :views, original_paths.first
      FileUtils.remove_entry(override_dir)
    end

    it 'injects custom script before </body>' do
      get '/'
      expect(last_response).to be_ok

      body = last_response.body
      expect(body).to include('<script src="/js/custom-analytics.js"></script>')
      # Verify it appears before the closing body tag
      script_pos = body.index('<script src="/js/custom-analytics.js"></script>')
      body_close_pos = body.index('</body>')
      expect(script_pos).to be < body_close_pos
    end
  end
end
