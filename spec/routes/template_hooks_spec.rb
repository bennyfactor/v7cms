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

  describe 'full-page homepage layouts' do
    around do |example|
      override_dir = Dir.mktmpdir('v7cms_test_views')
      layouts_dir = File.join(override_dir, 'layouts', 'homepage')
      FileUtils.mkdir_p(layouts_dir)
      File.write(File.join(layouts_dir, '_fullpage.erb'), '<% @full_page = true %><div id="FULLPAGE_HOOK">hi</div>')

      original_paths = app.settings.views_paths.dup
      app.settings.set :views_paths, [override_dir] + original_paths
      app.settings.set :views, override_dir
      # Layout discovery reads the file resolver, not the overridden view paths,
      # so bypass validation here and reset the cached singleton afterwards.
      Setting.instance.update_column(:layout_homepage, 'fullpage')
      Setting.clear_cache!

      example.run
    ensure
      app.settings.set :views_paths, original_paths
      app.settings.set :views, original_paths.first
      Setting.clear_cache!
      FileUtils.remove_entry(override_dir)
    end

    it 'omits the site header, main wrapper, and footer when the layout sets @full_page' do
      get '/'

      body = last_response.body
      expect(body).to include('FULLPAGE_HOOK')
      expect(body).not_to include('id="main-nav"')
      expect(body).not_to include('<main class="flex-1">')
      expect(body).not_to include('<footer class="bg-white')
      # The document shell still renders around the layout
      expect(body).to include('</body>')
    end
  end

  describe 'standard homepage layouts' do
    it 'renders the site header and footer by default' do
      get '/'
      expect(last_response.body).to include('id="main-nav"')
      expect(last_response.body).to include('<footer class="bg-white')
    end
  end
end
