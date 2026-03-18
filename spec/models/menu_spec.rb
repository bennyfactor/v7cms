# frozen_string_literal: true

require_relative '../spec_helper'

RSpec.describe V7CMS::Menu do
  describe 'validations' do
    it 'requires a name' do
      menu = described_class.new(name: nil)
      expect(menu).not_to be_valid
      expect(menu.errors[:name]).to include("can't be blank")
    end

    it 'auto-generates slug from name' do
      menu = described_class.create!(name: 'Main Navigation')
      expect(menu.slug).to eq('main-navigation')
    end

    it 'requires unique slug' do
      described_class.create!(name: 'First', slug: 'first')
      duplicate = described_class.new(name: 'Another', slug: 'first')
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:slug]).to include('has already been taken')
    end

    it 'validates slug format' do
      menu = described_class.new(name: 'Test', slug: 'Invalid Slug!')
      expect(menu).not_to be_valid
      expect(menu.errors[:slug]).to include('only allows lowercase letters, numbers, hyphens, and underscores')
    end

    it 'validates location inclusion' do
      menu = described_class.new(name: 'Test', location: 'invalid')
      expect(menu).not_to be_valid
      expect(menu.errors[:location]).to be_present
    end

    it 'allows valid locations' do
      %w[header footer sidebar].each do |loc|
        menu = described_class.new(name: "Test #{loc}", location: loc)
        menu.valid?
        expect(menu.errors[:location]).to be_empty
      end
    end

    it 'allows blank location' do
      menu = described_class.new(name: 'Unassigned')
      menu.valid?
      expect(menu.errors[:location]).to be_empty
    end

    it 'enforces unique location' do
      described_class.create!(name: 'Header Menu', location: 'header')
      duplicate = described_class.new(name: 'Another Header', location: 'header')
      expect(duplicate).not_to be_valid
    end

    it 'allows multiple menus with no location' do
      described_class.create!(name: 'Menu A', location: nil)
      menu_b = described_class.new(name: 'Menu B', location: nil)
      expect(menu_b).to be_valid
    end
  end

  describe '.at_location' do
    it 'finds menu by location' do
      menu = described_class.create!(name: 'Footer', location: 'footer')
      expect(described_class.at_location('footer')).to eq(menu)
    end

    it 'returns nil for unassigned location' do
      expect(described_class.at_location('sidebar')).to be_nil
    end
  end

  describe '.by_slug' do
    it 'finds menu by slug' do
      menu = described_class.create!(name: 'Main')
      expect(described_class.by_slug('main')).to eq(menu)
    end
  end

  describe 'associations' do
    it 'destroys menu items when menu is destroyed' do
      menu = described_class.create!(name: 'Test')
      menu.menu_items.create!(label: 'Home', link_type: 'custom', url: '/')
      expect { menu.destroy }.to change(V7CMS::MenuItem, :count).by(-1)
    end
  end
end
