# frozen_string_literal: true

require_relative '../spec_helper'

RSpec.describe V7CMS::MenuHelper do
  describe '.render_menu' do
    it 'returns empty string when no menu exists for location' do
      expect(described_class.render_menu('header')).to eq('')
    end

    it 'renders a simple menu with links' do
      menu = V7CMS::Menu.create!(name: 'Main', location: 'header')
      menu.menu_items.create!(label: 'Home', link_type: 'custom', url: '/', position: 0)
      menu.menu_items.create!(label: 'About', link_type: 'custom', url: '/about', position: 1)

      html = described_class.render_menu('header')
      expect(html).to include('Home')
      expect(html).to include('About')
      expect(html).to include('href="/"')
      expect(html).to include('href="/about"')
    end

    it 'looks up by location first, then slug' do
      menu = V7CMS::Menu.create!(name: 'Custom', slug: 'custom-nav', location: 'header')
      menu.menu_items.create!(label: 'Test', link_type: 'custom', url: '/')

      html = described_class.render_menu('header')
      expect(html).to include('Test')

      html = described_class.render_menu('custom-nav')
      expect(html).to include('Test')
    end

    it 'renders dropdown children with group-hover' do
      menu = V7CMS::Menu.create!(name: 'Main', location: 'header')
      parent = menu.menu_items.create!(label: 'Blog', link_type: 'custom', url: '/blog', position: 0)
      menu.menu_items.create!(label: 'Archives', link_type: 'custom', url: '/archives', position: 0, parent: parent)

      html = described_class.render_menu('header')
      expect(html).to include('Blog')
      expect(html).to include('Archives')
      expect(html).to include('group')
      expect(html).to include('group-hover')
    end

    it 'adds target="_blank" for items with target set' do
      menu = V7CMS::Menu.create!(name: 'Main', location: 'header')
      menu.menu_items.create!(label: 'External', link_type: 'custom', url: 'https://example.com', target: '_blank')

      html = described_class.render_menu('header')
      expect(html).to include('target="_blank"')
    end

    it 'renders page links with correct href' do
      page = V7CMS::Page.create!(title: 'About Us')
      menu = V7CMS::Menu.create!(name: 'Main', location: 'header')
      menu.menu_items.create!(label: 'About', link_type: 'page', linkable: page, position: 0)

      html = described_class.render_menu('header')
      expect(html).to include("href=\"/#{page.full_slug_path}\"")
    end

    it 'renders footer menu differently' do
      menu = V7CMS::Menu.create!(name: 'Footer', location: 'footer')
      menu.menu_items.create!(label: 'Privacy', link_type: 'custom', url: '/privacy', position: 0)

      html = described_class.render_menu('footer')
      expect(html).to include('Privacy')
      expect(html).to include('href="/privacy"')
    end
  end
end
