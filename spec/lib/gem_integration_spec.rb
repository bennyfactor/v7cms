# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'V7CMS Gem Integration' do
  describe 'V7CMS module' do
    it 'defines VERSION' do
      expect(V7CMS::VERSION).to match(/\d+\.\d+\.\d+/)
    end

    it 'provides project_root' do
      expect(V7CMS.project_root).to be_a(String)
      expect(File.directory?(V7CMS.project_root)).to be true
    end

    it 'provides gem_root' do
      expect(V7CMS.gem_root).to be_a(String)
      expect(File.directory?(V7CMS.gem_root)).to be true
    end

    it 'provides file_resolver' do
      expect(V7CMS.file_resolver).to be_a(V7CMS::FileResolver)
    end
  end

  describe 'V7CMS::Application' do
    it 'is a Sinatra application' do
      expect(V7CMS::Application.ancestors).to include(Sinatra::Base)
    end

    it 'has routes defined' do
      # Check that some core routes exist
      routes = V7CMS::Application.routes
      expect(routes['GET']).not_to be_empty
      expect(routes['POST']).not_to be_empty
    end
  end

  describe 'V7CMS Models' do
    it 'provides User model' do
      expect(V7CMS::User).to be < ActiveRecord::Base
    end

    it 'provides Post model' do
      expect(V7CMS::Post).to be < ActiveRecord::Base
    end

    it 'provides Page model' do
      expect(V7CMS::Page).to be < ActiveRecord::Base
    end

    it 'provides Comment model' do
      expect(V7CMS::Comment).to be < ActiveRecord::Base
    end

    it 'provides Setting model' do
      expect(V7CMS::Setting).to be < ActiveRecord::Base
    end

    it 'provides Theme model' do
      expect(V7CMS::Theme).to be < ActiveRecord::Base
    end

    it 'provides Redirect model' do
      expect(V7CMS::Redirect).to be < ActiveRecord::Base
    end
  end

  describe 'V7CMS Services' do
    it 'provides FeedGenerator' do
      expect(V7CMS::FeedGenerator).to be_a(Class)
    end

    it 'provides GravatarService' do
      expect(V7CMS::GravatarService).to be_a(Class)
    end

    it 'provides HtaccessGenerator' do
      expect(V7CMS::HtaccessGenerator).to be_a(Class)
    end

    it 'provides PageRenderer' do
      expect(V7CMS::PageRenderer).to be_a(Class)
    end

    it 'provides PostRenderer' do
      expect(V7CMS::PostRenderer).to be_a(Class)
    end

    it 'provides ThemeGenerator' do
      expect(V7CMS::ThemeGenerator).to be_a(Class)
    end
  end

  describe 'V7CMS Helpers' do
    it 'provides AuthHelper' do
      expect(V7CMS::AuthHelper).to be_a(Module)
    end

    it 'AuthHelper has current_user method' do
      expect(V7CMS::AuthHelper.instance_methods).to include(:current_user)
    end

    it 'AuthHelper has logged_in? method' do
      expect(V7CMS::AuthHelper.instance_methods).to include(:logged_in?)
    end

    it 'AuthHelper has require_login method' do
      expect(V7CMS::AuthHelper.instance_methods).to include(:require_login)
    end
  end

  describe 'Backward Compatibility' do
    it 'CMS is aliased to V7CMS::Application' do
      expect(CMS).to eq(V7CMS::Application)
    end

    it 'provides non-namespaced model aliases' do
      expect(User).to eq(V7CMS::User)
      expect(Post).to eq(V7CMS::Post)
      expect(Page).to eq(V7CMS::Page)
      expect(Comment).to eq(V7CMS::Comment)
      expect(Setting).to eq(V7CMS::Setting)
      expect(Theme).to eq(V7CMS::Theme)
      expect(Redirect).to eq(V7CMS::Redirect)
    end

    it 'provides non-namespaced service aliases' do
      expect(FeedGenerator).to eq(V7CMS::FeedGenerator)
      expect(GravatarService).to eq(V7CMS::GravatarService)
      expect(HtaccessGenerator).to eq(V7CMS::HtaccessGenerator)
      expect(PageRenderer).to eq(V7CMS::PageRenderer)
      expect(PostRenderer).to eq(V7CMS::PostRenderer)
      expect(ThemeGenerator).to eq(V7CMS::ThemeGenerator)
    end

    it 'provides non-namespaced helper alias' do
      expect(AuthHelper).to eq(V7CMS::AuthHelper)
    end
  end
end
