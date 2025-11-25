require_relative '../spec_helper'

RSpec.describe 'Comments API' do
  let(:test_post) { Post.create!(title: 'Test Post', slug: 'test-post', content: 'Test content', published: true) }

  describe 'GET /api/posts/:id/comments' do
    before do
      @approved1 = Comment.create!(
        post: test_post,
        author_name: 'John Doe',
        author_email: 'john@example.com',
        content: 'First comment',
        approved: true,
        created_at: 1.day.ago
      )
      @approved2 = Comment.create!(
        post: test_post,
        author_name: 'Jane Smith',
        author_email: 'jane@example.com',
        content: 'Second comment',
        approved: true,
        created_at: Time.now
      )
      @pending = Comment.create!(
        post: test_post,
        author_name: 'Pending User',
        author_email: 'pending@example.com',
        content: 'Pending comment',
        approved: false
      )
      @spam = Comment.create!(
        post: test_post,
        author_name: 'Spammer',
        author_email: 'spam@example.com',
        content: 'Spam comment',
        spam: true
      )
    end

    it 'returns only approved comments' do
      get "/api/posts/#{test_post.id}/comments"

      expect(last_response).to be_ok
      data = JSON.parse(last_response.body)
      comment_ids = data['comments'].map { |c| c['id'] }

      expect(comment_ids).to include(@approved1.id)
      expect(comment_ids).to include(@approved2.id)
      expect(comment_ids).not_to include(@pending.id)
      expect(comment_ids).not_to include(@spam.id)
    end

    it 'orders comments oldest first' do
      get "/api/posts/#{test_post.id}/comments"

      data = JSON.parse(last_response.body)
      expect(data['comments'].first['id']).to eq(@approved1.id)
      expect(data['comments'].last['id']).to eq(@approved2.id)
    end

    it 'includes comment fields' do
      get "/api/posts/#{test_post.id}/comments"

      data = JSON.parse(last_response.body)
      comment = data['comments'].first

      expect(comment['author_name']).to eq('John Doe')
      expect(comment['author_email']).to be_nil
      expect(comment['content']).to eq('First comment')
      expect(comment['created_at']).to be_present
    end

    it 'supports pagination with limit and offset' do
      25.times do |i|
        Comment.create!(
          post: test_post,
          author_name: "User #{i}",
          author_email: "user#{i}@example.com",
          content: "Comment #{i}",
          approved: true,
          created_at: i.minutes.ago
        )
      end

      get "/api/posts/#{test_post.id}/comments?limit=20&offset=0"

      data = JSON.parse(last_response.body)
      expect(data['comments'].size).to eq(20)
      expect(data['pagination']['total']).to eq(27) # 25 + 2 from before block
      expect(data['pagination']['limit']).to eq(20)
      expect(data['pagination']['offset']).to eq(0)
    end

    it 'defaults to limit 20 when not specified' do
      25.times do |i|
        Comment.create!(
          post: test_post,
          author_name: "User #{i}",
          author_email: "user#{i}@example.com",
          content: "Comment #{i}",
          approved: true
        )
      end

      get "/api/posts/#{test_post.id}/comments"

      data = JSON.parse(last_response.body)
      expect(data['comments'].size).to eq(20)
    end

    it 'returns 404 for non-existent post' do
      get "/api/posts/99999/comments"
      expect(last_response.status).to eq(404)
    end
  end

  describe 'POST /api/posts/:id/comments' do
    it 'creates comment with valid reCAPTCHA score' do
      allow_any_instance_of(CMS).to receive(:verify_recaptcha_v3).and_return(0.9)

      post "/api/posts/#{test_post.id}/comments", {
        author_name: 'John Doe',
        author_email: 'john@example.com',
        author_url: 'https://example.com',
        content: 'Great post!',
        recaptcha_token: 'valid_token'
      }.to_json, { 'CONTENT_TYPE' => 'application/json' }

      expect(last_response).to be_ok
      data = JSON.parse(last_response.body)
      expect(data['success']).to eq(true)

      comment = Comment.last
      expect(comment.author_name).to eq('John Doe')
      expect(comment.approved).to eq(false)
      expect(comment.recaptcha_score).to eq(0.9)
    end

    it 'rejects comment with low reCAPTCHA score' do
      allow_any_instance_of(CMS).to receive(:verify_recaptcha_v3).and_return(0.3)

      post "/api/posts/#{test_post.id}/comments", {
        author_name: 'Bot',
        author_email: 'bot@example.com',
        content: 'Spam!',
        recaptcha_token: 'bot_token'
      }.to_json, { 'CONTENT_TYPE' => 'application/json' }

      expect(last_response.status).to eq(400)
      data = JSON.parse(last_response.body)
      expect(data['error']).to include('reCAPTCHA')
    end

    it 'validates required fields' do
      allow_any_instance_of(CMS).to receive(:verify_recaptcha_v3).and_return(0.9)

      post "/api/posts/#{test_post.id}/comments", {
        author_name: '',
        author_email: 'john@example.com',
        content: 'Test',
        recaptcha_token: 'valid_token'
      }.to_json, { 'CONTENT_TYPE' => 'application/json' }

      expect(last_response.status).to eq(400)
      data = JSON.parse(last_response.body)
      expect(data['error']).to be_present
    end

    it 'stores IP address' do
      allow_any_instance_of(CMS).to receive(:verify_recaptcha_v3).and_return(0.9)

      post "/api/posts/#{test_post.id}/comments", {
        author_name: 'John',
        author_email: 'john@example.com',
        content: 'Test',
        recaptcha_token: 'valid_token'
      }.to_json, { 'CONTENT_TYPE' => 'application/json', 'REMOTE_ADDR' => '192.168.1.1' }

      comment = Comment.last
      expect(comment.ip_address).to eq('192.168.1.1')
    end

    it 'returns 404 for non-existent post' do
      post "/api/posts/99999/comments", {
        author_name: 'John',
        author_email: 'john@example.com',
        content: 'Test',
        recaptcha_token: 'valid_token'
      }.to_json, { 'CONTENT_TYPE' => 'application/json' }

      expect(last_response.status).to eq(404)
    end
  end
end
