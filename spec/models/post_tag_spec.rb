require 'spec_helper'

RSpec.describe V7CMS::PostTag do
  describe 'validations' do
    it 'requires a post' do
      tag = V7CMS::Tag.create!(name: 'Ruby')
      pt = described_class.new(tag: tag)
      expect(pt).not_to be_valid
    end

    it 'requires a tag' do
      post = V7CMS::Post.create!(title: 'Test')
      pt = described_class.new(post: post)
      expect(pt).not_to be_valid
    end

    it 'prevents duplicate post-tag pairs' do
      tag = V7CMS::Tag.create!(name: 'Ruby')
      post = V7CMS::Post.create!(title: 'Test')
      described_class.create!(post: post, tag: tag)

      duplicate = described_class.new(post: post, tag: tag)
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:tag_id]).to include('has already been taken')
    end

    it 'allows same tag on different posts' do
      tag = V7CMS::Tag.create!(name: 'Ruby')
      post1 = V7CMS::Post.create!(title: 'Post 1')
      post2 = V7CMS::Post.create!(title: 'Post 2')
      described_class.create!(post: post1, tag: tag)

      pt = described_class.new(post: post2, tag: tag)
      expect(pt).to be_valid
    end
  end
end
