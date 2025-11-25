require_relative '../spec_helper'

RSpec.describe Comment do
  let(:post) { Post.create!(title: 'Test Post', slug: 'test-post', content: 'Test', published: true) }

  describe 'validations' do
    it 'requires author_name' do
      comment = Comment.new(author_email: 'test@example.com', content: 'Test')
      expect(comment.valid?).to eq(false)
      expect(comment.errors[:author_name]).to include("can't be blank")
    end

    it 'requires author_email' do
      comment = Comment.new(author_name: 'John', content: 'Test')
      expect(comment.valid?).to eq(false)
      expect(comment.errors[:author_email]).to include("can't be blank")
    end

    it 'requires content' do
      comment = Comment.new(author_name: 'John', author_email: 'test@example.com')
      expect(comment.valid?).to eq(false)
      expect(comment.errors[:content]).to include("can't be blank")
    end

    it 'validates email format' do
      comment = Comment.new(author_name: 'John', author_email: 'invalid', content: 'Test', post: post)
      expect(comment.valid?).to eq(false)
      expect(comment.errors[:author_email]).to be_present
    end

    it 'validates author_name length' do
      comment = Comment.new(author_name: 'a' * 101, author_email: 'test@example.com', content: 'Test', post: post)
      expect(comment.valid?).to eq(false)
    end

    it 'validates content length' do
      comment = Comment.new(author_name: 'John', author_email: 'test@example.com', content: 'a' * 5001, post: post)
      expect(comment.valid?).to eq(false)
    end

    it 'allows valid URL for author_url' do
      comment = Comment.new(author_name: 'John', author_email: 'test@example.com', content: 'Test', author_url: 'https://example.com', post: post)
      expect(comment.valid?).to eq(true)
    end

    it 'allows blank author_url' do
      comment = Comment.new(author_name: 'John', author_email: 'test@example.com', content: 'Test', post: post)
      expect(comment.valid?).to eq(true)
    end
  end

  describe 'associations' do
    it 'belongs to post' do
      comment = Comment.new(author_name: 'John', author_email: 'test@example.com', content: 'Test', post: post)
      expect(comment.post).to eq(post)
    end
  end

  describe 'scopes' do
    before do
      @approved = Comment.create!(author_name: 'John', author_email: 'test@example.com', content: 'Approved', post: post, approved: true, spam: false)
      @pending = Comment.create!(author_name: 'Jane', author_email: 'jane@example.com', content: 'Pending', post: post, approved: false, spam: false)
      @spam = Comment.create!(author_name: 'Spammer', author_email: 'spam@example.com', content: 'Spam', post: post, approved: false, spam: true)
    end

    it 'approved scope returns only approved non-spam comments' do
      expect(Comment.approved).to include(@approved)
      expect(Comment.approved).not_to include(@pending)
      expect(Comment.approved).not_to include(@spam)
    end

    it 'pending scope returns only non-approved non-spam comments' do
      expect(Comment.pending).to include(@pending)
      expect(Comment.pending).not_to include(@approved)
      expect(Comment.pending).not_to include(@spam)
    end

    it 'spam scope returns only spam comments' do
      expect(Comment.spam).to include(@spam)
      expect(Comment.spam).not_to include(@approved)
      expect(Comment.spam).not_to include(@pending)
    end
  end

  describe '.pending_count' do
    it 'returns count of pending comments' do
      Comment.create!(author_name: 'John', author_email: 'test@example.com', content: 'Pending 1', post: post, approved: false, spam: false)
      Comment.create!(author_name: 'Jane', author_email: 'jane@example.com', content: 'Pending 2', post: post, approved: false, spam: false)
      Comment.create!(author_name: 'Bob', author_email: 'bob@example.com', content: 'Approved', post: post, approved: true, spam: false)

      expect(Comment.pending_count).to eq(2)
    end
  end
end
