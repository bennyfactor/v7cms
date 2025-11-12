require 'spec_helper'

RSpec.describe Post, type: :model do
  describe 'validations' do
    it 'requires title' do
      post = Post.new(content: 'Test content')
      expect(post).not_to be_valid
      expect(post.errors[:title]).to include("can't be blank")
    end

    it 'requires slug' do
      post = Post.new(title: 'Test Post', content: 'Test content')
      post.valid? # trigger callbacks
      expect(post.slug).not_to be_nil
    end

    it 'requires unique slug' do
      Post.create!(title: 'Test Post', slug: 'test-post', content: 'Content 1')
      post2 = Post.new(title: 'Test Post 2', slug: 'test-post', content: 'Content 2')

      expect(post2).not_to be_valid
      expect(post2.errors[:slug]).to include('has already been taken')
    end
  end

  describe 'slug generation' do
    it 'auto-generates slug from title if not provided' do
      post = Post.new(title: 'My Awesome Post', content: 'Content')
      post.valid?
      expect(post.slug).to eq('my-awesome-post')
    end

    it 'handles special characters in title' do
      post = Post.new(title: 'Hello, World! How are you?', content: 'Content')
      post.valid?
      expect(post.slug).to eq('hello-world-how-are-you')
    end

    it 'handles unicode characters' do
      post = Post.new(title: 'Café & Restaurant', content: 'Content')
      post.valid?
      expect(post.slug).to eq('caf-restaurant')
    end

    it 'preserves manually set slug' do
      post = Post.new(title: 'Test Post', slug: 'custom-slug', content: 'Content')
      post.valid?
      expect(post.slug).to eq('custom-slug')
    end
  end

  describe 'scopes' do
    before do
      Post.create!(title: 'Published 1', slug: 'pub1', content: 'Content', published: true)
      Post.create!(title: 'Draft 1', slug: 'draft1', content: 'Content', published: false)
      Post.create!(title: 'Published 2', slug: 'pub2', content: 'Content', published: true)
    end

    it 'has a published scope' do
      expect(Post.published.count).to eq(2)
      expect(Post.published.pluck(:title)).to contain_exactly('Published 1', 'Published 2')
    end

    it 'has a recent scope ordered by created_at desc' do
      posts = Post.recent
      expect(posts.first.title).to eq('Published 2')
      expect(posts.last.title).to eq('Published 1')
    end
  end

  describe 'default values' do
    it 'defaults published to false' do
      post = Post.create!(title: 'Test', slug: 'test', content: 'Content')
      expect(post.published).to be false
    end
  end
end
