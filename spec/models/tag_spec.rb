require 'spec_helper'

RSpec.describe V7CMS::Tag do
  describe 'validations' do
    it 'requires a name' do
      tag = V7CMS::Tag.new(name: nil)
      expect(tag).not_to be_valid
      expect(tag.errors[:name]).to include("can't be blank")
    end

    it 'requires a unique name (case-insensitive)' do
      V7CMS::Tag.create!(name: 'Ruby')
      tag = V7CMS::Tag.new(name: 'ruby')
      expect(tag).not_to be_valid
      expect(tag.errors[:name]).to include('has already been taken')
    end

    it 'limits name to 100 characters' do
      tag = V7CMS::Tag.new(name: 'a' * 101)
      expect(tag).not_to be_valid
      expect(tag.errors[:name]).to include('is too long (maximum is 100 characters)')
    end

    it 'is valid with a name' do
      tag = V7CMS::Tag.new(name: 'Ruby')
      expect(tag).to be_valid
    end
  end

  describe 'slug generation' do
    it 'auto-generates slug from name on create' do
      tag = V7CMS::Tag.create!(name: 'Web Development')
      expect(tag.slug).to eq('web-development')
    end

    it 'handles special characters in slug' do
      tag = V7CMS::Tag.create!(name: 'C++ Programming!')
      expect(tag.slug).to eq('c-programming')
    end

    it 'does not change slug on update' do
      tag = V7CMS::Tag.create!(name: 'Ruby')
      tag.update!(name: 'Ruby Language')
      expect(tag.slug).to eq('ruby')
    end
  end

  describe 'associations' do
    it 'has many posts through post_tags' do
      tag = V7CMS::Tag.create!(name: 'Ruby')
      post = V7CMS::Post.create!(title: 'Test Post')
      V7CMS::PostTag.create!(post: post, tag: tag)

      expect(tag.posts).to include(post)
    end

    it 'destroys post_tags when destroyed' do
      tag = V7CMS::Tag.create!(name: 'Ruby')
      post = V7CMS::Post.create!(title: 'Test Post')
      V7CMS::PostTag.create!(post: post, tag: tag)

      expect { tag.destroy }.to change(V7CMS::PostTag, :count).by(-1)
    end
  end

  describe 'scopes' do
    it 'orders by name alphabetically' do
      z = V7CMS::Tag.create!(name: 'Zig')
      a = V7CMS::Tag.create!(name: 'Ada')
      m = V7CMS::Tag.create!(name: 'ML')

      expect(V7CMS::Tag.ordered).to eq([a, m, z])
    end
  end

  describe '#posts_count' do
    it 'returns the number of associated posts' do
      tag = V7CMS::Tag.create!(name: 'Ruby')
      2.times { |i| V7CMS::PostTag.create!(post: V7CMS::Post.create!(title: "Post #{i}"), tag: tag) }

      expect(tag.posts_count).to eq(2)
    end

    it 'returns 0 when no posts are tagged' do
      tag = V7CMS::Tag.create!(name: 'Empty')
      expect(tag.posts_count).to eq(0)
    end
  end
end
