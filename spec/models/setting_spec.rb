require 'spec_helper'

RSpec.describe Setting do
  # Clear cache before each test to prevent test pollution
  before do
    Setting.clear_cache! if Setting.respond_to?(:clear_cache!)
  end

  describe '.instance' do
    it 'returns a settings record' do
      setting = Setting.instance
      expect(setting).to be_a(Setting)
      expect(setting).to be_persisted
    end

    it 'returns the same record on multiple calls' do
      first = Setting.instance
      second = Setting.instance
      expect(first.id).to eq(second.id)
    end

    it 'creates a settings record if none exists' do
      Setting.delete_all  # Ensure clean state
      Setting.clear_cache!  # Clear cache after deletion
      expect(Setting.count).to eq(0)
      Setting.instance
      expect(Setting.count).to eq(1)
    end
  end

  describe '.get' do
    before { Setting.instance }

    it 'returns the value for a given key' do
      expect(Setting.get(:site_title)).to eq('v7cms')
    end

    it 'returns nil for invalid key' do
      expect(Setting.get(:nonexistent_key)).to be_nil
    end
  end

  describe 'caching' do
    it 'caches instance in memory after first load' do
      # Track database queries
      queries = []
      ActiveSupport::Notifications.subscribe('sql.active_record') do |*, payload|
        queries << payload[:sql] if payload[:sql] =~ /SELECT.*FROM.*settings/
      end

      # First call should hit database
      Setting.instance
      first_query_count = queries.length

      # Second call should use cache (no new queries)
      queries.clear
      Setting.instance
      second_query_count = queries.length

      expect(first_query_count).to be > 0
      expect(second_query_count).to eq(0)
    end

    it 'clears cache when settings are updated' do
      # Load instance into cache
      setting = Setting.instance
      original_object_id = setting.object_id

      # Verify it's cached (same object returned)
      cached_setting = Setting.instance
      expect(cached_setting.object_id).to eq(original_object_id)

      # Update the setting (this should clear the cache)
      setting.update!(site_title: 'Updated Title')

      # Next call should load a fresh instance from database (different object)
      fresh_setting = Setting.instance
      expect(fresh_setting.object_id).not_to eq(original_object_id)
      expect(fresh_setting.site_title).to eq('Updated Title')
    end

    it 'provides thread-safe cache access' do
      threads = []
      results = []
      mutex = Mutex.new

      # Spawn multiple threads that all try to access instance simultaneously
      10.times do
        threads << Thread.new do
          instance = Setting.instance
          mutex.synchronize { results << instance.id }
        end
      end

      # Wait for all threads to complete
      threads.each(&:join)

      # All threads should get the same instance (same ID)
      expect(results.uniq.length).to eq(1)
    end
  end

  describe 'validations' do
    let(:setting) { Setting.instance }

    describe 'site_title' do
      it 'requires site_title' do
        setting.site_title = nil
        expect(setting).not_to be_valid
        expect(setting.errors[:site_title]).to include("can't be blank")
      end

      it 'validates maximum length of 100 characters' do
        setting.site_title = 'a' * 101
        expect(setting).not_to be_valid
        expect(setting.errors[:site_title]).to include('is too long (maximum is 100 characters)')
      end
    end

    describe 'site_tagline' do
      it 'validates maximum length of 200 characters' do
        setting.site_tagline = 'a' * 201
        expect(setting).not_to be_valid
      end
    end

    describe 'site_author' do
      it 'validates maximum length of 100 characters' do
        setting.site_author = 'a' * 101
        expect(setting).not_to be_valid
      end
    end

    describe 'welcome_title' do
      it 'requires welcome_title' do
        setting.welcome_title = nil
        expect(setting).not_to be_valid
        expect(setting.errors[:welcome_title]).to include("can't be blank")
      end

      it 'validates maximum length of 200 characters' do
        setting.welcome_title = 'a' * 201
        expect(setting).not_to be_valid
      end
    end

    describe 'welcome_subtitle' do
      it 'validates maximum length of 300 characters' do
        setting.welcome_subtitle = 'a' * 301
        expect(setting).not_to be_valid
      end
    end

    describe 'footer_text' do
      it 'validates maximum length of 300 characters' do
        setting.footer_text = 'a' * 301
        expect(setting).not_to be_valid
      end
    end

    describe 'meta_keywords' do
      it 'validates maximum length of 500 characters' do
        setting.meta_keywords = 'a' * 501
        expect(setting).not_to be_valid
      end
    end

    describe 'contact_email' do
      it 'allows valid email addresses' do
        setting.contact_email = 'user@example.com'
        expect(setting).to be_valid
      end

      it 'allows blank email' do
        setting.contact_email = ''
        expect(setting).to be_valid
      end

      it 'rejects invalid email addresses' do
        setting.contact_email = 'invalid-email'
        expect(setting).not_to be_valid
        expect(setting.errors[:contact_email]).to include('must be a valid email address')
      end
    end

    describe 'github_url' do
      it 'allows valid URLs' do
        setting.github_url = 'https://github.com/user'
        expect(setting).to be_valid
      end

      it 'allows blank URL' do
        setting.github_url = ''
        expect(setting).to be_valid
      end

      it 'rejects invalid URLs' do
        setting.github_url = 'not a url'
        expect(setting).not_to be_valid
        expect(setting.errors[:github_url]).to include('must be a valid URL')
      end
    end

    describe 'social_url' do
      it 'allows valid URLs' do
        setting.social_url = 'https://twitter.com/user'
        expect(setting).to be_valid
      end

      it 'allows blank URL' do
        setting.social_url = ''
        expect(setting).to be_valid
      end

      it 'rejects invalid URLs' do
        setting.social_url = 'not a url'
        expect(setting).not_to be_valid
        expect(setting.errors[:social_url]).to include('must be a valid URL')
      end
    end

    describe 'posts_per_page' do
      it 'requires a positive integer' do
        setting.posts_per_page = 0
        expect(setting).not_to be_valid
      end

      it 'rejects values over 100' do
        setting.posts_per_page = 101
        expect(setting).not_to be_valid
      end

      it 'rejects non-integers' do
        setting.posts_per_page = 5.5
        expect(setting).not_to be_valid
      end

      it 'allows valid values' do
        setting.posts_per_page = 20
        expect(setting).to be_valid
      end
    end

    describe 'date_format' do
      it 'requires date_format' do
        setting.date_format = nil
        expect(setting).not_to be_valid
      end
    end

    describe 'allow_comments validation' do
      let(:setting) { Setting.instance }

      it 'accepts true' do
        setting.allow_comments = true
        expect(setting).to be_valid
      end

      it 'accepts false' do
        setting.allow_comments = false
        expect(setting).to be_valid
      end

      it 'rejects nil' do
        setting.allow_comments = nil
        expect(setting).not_to be_valid
        expect(setting.errors[:allow_comments]).to include('is not included in the list')
      end
    end

    describe 'reserved_redirect_paths' do
      it 'validates maximum length of 1000 characters' do
        setting.reserved_redirect_paths = 'a' * 1001
        expect(setting).not_to be_valid
        expect(setting.errors[:reserved_redirect_paths]).to include('is too long (maximum is 1000 characters)')
      end

      it 'allows blank value' do
        setting.reserved_redirect_paths = ''
        expect(setting).to be_valid
      end

      it 'allows valid comma-separated paths' do
        setting.reserved_redirect_paths = '/admin,/api,/custom'
        expect(setting).to be_valid
      end
    end

    describe 'layout_homepage' do
      it 'accepts valid layout values' do
        Setting::HOMEPAGE_LAYOUTS.each do |layout|
          setting.layout_homepage = layout
          expect(setting).to be_valid, "Expected #{layout} to be valid"
        end
      end

      it 'rejects invalid layout values' do
        setting.layout_homepage = 'invalid_layout'
        expect(setting).not_to be_valid
        expect(setting.errors[:layout_homepage].first).to include('must be a valid layout option')
      end

      it 'defines all expected layouts' do
        expected_layouts = %w[blog_list blog_grid hero_grid magazine minimal portfolio landing]
        expect(Setting::HOMEPAGE_LAYOUTS).to match_array(expected_layouts)
      end
    end
  end

  describe 'defaults' do
    let(:setting) { Setting.instance }

    it 'has default site_title' do
      expect(setting.site_title).to eq('v7cms')
    end

    it 'has default welcome_title' do
      expect(setting.welcome_title).to eq('Welcome to v7cms')
    end

    it 'has default footer_text' do
      expect(setting.footer_text).to eq('Powered by v7cms')
    end

    it 'has default show_copyright_year as true' do
      expect(setting.show_copyright_year).to be true
    end

    it 'has default posts_per_page' do
      expect(setting.posts_per_page).to eq(10)
    end

    it 'has default date_format' do
      expect(setting.date_format).to eq('%B %d, %Y')
    end

    it 'has default reserved_redirect_paths' do
      expect(setting.reserved_redirect_paths).to eq('/,/admin,/api,/auth,/feed,/posts,/pages')
    end

    it 'has default layout_homepage' do
      expect(setting.layout_homepage).to eq('blog_list')
    end
  end

  describe '#reserved_paths_array' do
    let(:setting) { Setting.instance }

    it 'returns array of paths from comma-separated string' do
      setting.update!(reserved_redirect_paths: '/admin,/api,/custom')
      expect(setting.reserved_paths_array).to eq(['/admin', '/api', '/custom'])
    end

    it 'strips whitespace from paths' do
      setting.update!(reserved_redirect_paths: '/admin, /api , /custom')
      expect(setting.reserved_paths_array).to eq(['/admin', '/api', '/custom'])
    end

    it 'removes empty paths' do
      setting.update!(reserved_redirect_paths: '/admin,,/api,')
      expect(setting.reserved_paths_array).to eq(['/admin', '/api'])
    end

    it 'returns empty array when value is blank' do
      setting.update!(reserved_redirect_paths: '')
      expect(setting.reserved_paths_array).to eq([])
    end

    it 'returns empty array when value is nil' do
      setting.update!(reserved_redirect_paths: nil)
      expect(setting.reserved_paths_array).to eq([])
    end
  end

  describe '#reset_to_defaults!' do
    it 'resets all settings to default values' do
      setting = Setting.instance
      setting.update!(
        site_title: 'Custom Title',
        welcome_title: 'Custom Welcome',
        footer_text: 'Custom Footer',
        posts_per_page: 50
      )

      setting.reset_to_defaults!

      expect(setting.site_title).to eq('v7cms')
      expect(setting.welcome_title).to eq('Welcome to v7cms')
      expect(setting.footer_text).to eq('Powered by v7cms')
      expect(setting.posts_per_page).to eq(10)
    end

    it 'resets allow_comments to true' do
      setting = Setting.instance
      setting.update!(allow_comments: false)
      setting.reset_to_defaults!
      expect(setting.allow_comments).to be true
    end

    it 'resets reserved_redirect_paths to defaults' do
      setting = Setting.instance
      setting.update!(reserved_redirect_paths: '/custom,/other')
      setting.reset_to_defaults!
      expect(setting.reserved_redirect_paths).to eq('/,/admin,/api,/auth,/feed,/posts,/pages')
    end

    it 'resets layout_homepage to defaults' do
      setting = Setting.instance
      setting.update!(layout_homepage: 'magazine')
      setting.reset_to_defaults!
      expect(setting.layout_homepage).to eq('blog_list')
    end
  end
end
