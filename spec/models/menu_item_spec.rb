# frozen_string_literal: true

require_relative '../spec_helper'

RSpec.describe V7CMS::MenuItem do
  let(:menu) { V7CMS::Menu.create!(name: 'Test Menu') }

  describe 'validations' do
    it 'requires a label' do
      item = described_class.new(menu: menu, link_type: 'custom', url: '/')
      item.label = nil
      expect(item).not_to be_valid
      expect(item.errors[:label]).to include("can't be blank")
    end

    it 'requires a valid link_type' do
      item = described_class.new(menu: menu, label: 'Test', link_type: 'invalid')
      expect(item).not_to be_valid
      expect(item.errors[:link_type]).to be_present
    end

    it 'allows valid link_types' do
      %w[page post custom].each do |lt|
        item = described_class.new(menu: menu, label: 'Test', link_type: lt)
        item.url = '/' if lt == 'custom'
        if lt == 'page'
          item.linkable = V7CMS::Page.create!(title: "Page #{lt}")
        elsif lt == 'post'
          item.linkable = V7CMS::Post.create!(title: "Post #{lt}")
        end
        item.valid?
        expect(item.errors[:link_type]).to be_empty
      end
    end

    it 'requires url for custom link_type' do
      item = described_class.new(menu: menu, label: 'Test', link_type: 'custom', url: nil)
      expect(item).not_to be_valid
      expect(item.errors[:url]).to include("can't be blank")
    end

    it 'requires linkable for page link_type' do
      item = described_class.new(menu: menu, label: 'Test', link_type: 'page', linkable: nil)
      expect(item).not_to be_valid
      expect(item.errors[:linkable]).to be_present
    end

    it 'requires linkable for post link_type' do
      item = described_class.new(menu: menu, label: 'Test', link_type: 'post', linkable: nil)
      expect(item).not_to be_valid
      expect(item.errors[:linkable]).to be_present
    end
  end

  describe 'max depth enforcement' do
    it 'allows top-level items to have children' do
      parent = described_class.create!(menu: menu, label: 'Parent', link_type: 'custom', url: '/')
      child = described_class.new(menu: menu, label: 'Child', link_type: 'custom', url: '/child', parent: parent)
      expect(child).to be_valid
    end

    it 'prevents children from having children (max 2 levels)' do
      parent = described_class.create!(menu: menu, label: 'Parent', link_type: 'custom', url: '/')
      child = described_class.create!(menu: menu, label: 'Child', link_type: 'custom', url: '/child', parent: parent)
      grandchild = described_class.new(menu: menu, label: 'Grandchild', link_type: 'custom', url: '/gc', parent: child)
      expect(grandchild).not_to be_valid
      expect(grandchild.errors[:parent_id]).to be_present
    end
  end

  describe 'circular reference prevention' do
    it 'prevents self-reference' do
      item = described_class.create!(menu: menu, label: 'Test', link_type: 'custom', url: '/')
      item.parent_id = item.id
      expect(item).not_to be_valid
      expect(item.errors[:parent_id]).to be_present
    end
  end

  describe '#href' do
    it 'returns url for custom links' do
      item = described_class.new(link_type: 'custom', url: 'https://example.com')
      expect(item.href).to eq('https://example.com')
    end

    it 'returns page path for page links' do
      page = V7CMS::Page.create!(title: 'About')
      item = described_class.new(link_type: 'page', linkable: page)
      expect(item.href).to eq("/#{page.full_slug_path}")
    end

    it 'returns post path for post links' do
      post = V7CMS::Post.create!(title: 'My Post')
      item = described_class.new(link_type: 'post', linkable: post)
      expect(item.href).to eq("/posts/#{post.slug}")
    end

    it 'returns # when linkable is missing' do
      item = described_class.new(link_type: 'page', linkable: nil)
      expect(item.href).to eq('#')
    end
  end

  describe '#to_nested_hash' do
    it 'returns hash with children' do
      parent = described_class.create!(menu: menu, label: 'Parent', link_type: 'custom', url: '/')
      described_class.create!(menu: menu, label: 'Child', link_type: 'custom', url: '/child', parent: parent)

      hash = parent.reload.to_nested_hash
      expect(hash[:label]).to eq('Parent')
      expect(hash[:href]).to eq('/')
      expect(hash[:children].length).to eq(1)
      expect(hash[:children].first[:label]).to eq('Child')
    end
  end

  describe 'associations' do
    it 'destroys children when parent is destroyed' do
      parent = described_class.create!(menu: menu, label: 'Parent', link_type: 'custom', url: '/')
      described_class.create!(menu: menu, label: 'Child', link_type: 'custom', url: '/child', parent: parent)
      expect { parent.destroy }.to change(described_class, :count).by(-2)
    end
  end
end
