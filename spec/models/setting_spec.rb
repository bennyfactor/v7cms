require 'spec_helper'

RSpec.describe Setting do
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
  end
end
