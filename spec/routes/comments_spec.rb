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

    it 'returns 403 when comments are disabled globally' do
      allow_any_instance_of(CMS).to receive(:verify_recaptcha_v3).and_return(0.9)
      post = Post.create!(title: 'Test', slug: 'test', published: true, comments_enabled: true)
      Setting.instance.update!(allow_comments: false)

      post "/api/posts/#{post.id}/comments", {
        author_name: 'Test',
        author_email: 'test@example.com',
        content: 'Test comment',
        recaptcha_token: 'test_token'
      }.to_json, { 'CONTENT_TYPE' => 'application/json' }

      expect(last_response.status).to eq(403)
      json = JSON.parse(last_response.body)
      expect(json['error']).to eq('Comments are closed for this post')
    end

    it 'returns 403 when comments are disabled for post' do
      allow_any_instance_of(CMS).to receive(:verify_recaptcha_v3).and_return(0.9)
      post = Post.create!(title: 'Test', slug: 'test', published: true, comments_enabled: false)
      Setting.instance.update!(allow_comments: true)

      post "/api/posts/#{post.id}/comments", {
        author_name: 'Test',
        author_email: 'test@example.com',
        content: 'Test comment',
        recaptcha_token: 'test_token'
      }.to_json, { 'CONTENT_TYPE' => 'application/json' }

      expect(last_response.status).to eq(403)
      json = JSON.parse(last_response.body)
      expect(json['error']).to eq('Comments are closed for this post')
    end
  end

  describe 'Admin Comments API' do
    let(:user) { User.create!(email: 'admin@example.com', name: 'Admin', provider: 'google_oauth2', uid: '12345', admin: true) }

    def login_as(user)
      env 'rack.session', { user_id: user.id }
    end

    describe 'GET /api/comments' do
      before do
        @pending = Comment.create!(post: test_post, author_name: 'Pending', author_email: 'pending@example.com', content: 'Pending', approved: false, spam: false)
        @approved = Comment.create!(post: test_post, author_name: 'Approved', author_email: 'approved@example.com', content: 'Approved', approved: true, spam: false)
        @spam = Comment.create!(post: test_post, author_name: 'Spam', author_email: 'spam@example.com', content: 'Spam', approved: false, spam: true)
      end

      it 'requires authentication' do
        get '/api/comments'
        expect(last_response.status).to eq(401)
      end

      it 'returns all comments with post info when authenticated' do
        login_as(user)

        get '/api/comments'

        expect(last_response).to be_ok
        data = JSON.parse(last_response.body)
        expect(data['comments'].size).to eq(3)

        comment = data['comments'].find { |c| c['id'] == @pending.id }
        expect(comment['post']['title']).to eq('Test Post')
        expect(comment['post']['slug']).to eq('test-post')
      end

      it 'filters by status=pending' do
        login_as(user)

        get '/api/comments?status=pending'
        data = JSON.parse(last_response.body)
        expect(data['comments'].size).to eq(1)
        expect(data['comments'].first['id']).to eq(@pending.id)
      end

      it 'filters by status=approved' do
        login_as(user)

        get '/api/comments?status=approved'
        data = JSON.parse(last_response.body)
        expect(data['comments'].size).to eq(1)
        expect(data['comments'].first['id']).to eq(@approved.id)
      end

      it 'filters by status=spam' do
        login_as(user)

        get '/api/comments?status=spam'
        data = JSON.parse(last_response.body)
        expect(data['comments'].size).to eq(1)
        expect(data['comments'].first['id']).to eq(@spam.id)
      end

      it 'returns all comments when no status filter is provided' do
        login_as(user)

        get '/api/comments'
        data = JSON.parse(last_response.body)
        expect(data['comments'].size).to eq(3)
      end
    end

    describe 'GET /api/comments/pending_count' do
      it 'returns pending count without authentication' do
        Comment.create!(post: test_post, author_name: 'Pending', author_email: 'pending@example.com', content: 'Pending', approved: false)

        get '/api/comments/pending_count'

        expect(last_response).to be_ok
        data = JSON.parse(last_response.body)
        expect(data['count']).to eq(1)
      end
    end

    describe 'PUT /api/comments/:id/approve' do
      let(:comment) { Comment.create!(post: test_post, author_name: 'John', author_email: 'john@example.com', content: 'Test', approved: false) }

      it 'requires authentication' do
        put "/api/comments/#{comment.id}/approve"
        expect(last_response.status).to eq(401)
      end

      it 'approves comment when authenticated' do
        login_as(user)

        put "/api/comments/#{comment.id}/approve"

        expect(last_response).to be_ok
        expect(comment.reload.approved).to eq(true)
        expect(comment.spam).to eq(false)
      end

      it 'returns 404 for non-existent comment' do
        login_as(user)

        put '/api/comments/99999/approve'

        expect(last_response.status).to eq(404)
        data = JSON.parse(last_response.body)
        expect(data['error']).to eq('Comment not found')
      end
    end

    describe 'PUT /api/comments/:id/spam' do
      let(:comment) { Comment.create!(post: test_post, author_name: 'John', author_email: 'john@example.com', content: 'Test', approved: false) }

      it 'requires authentication' do
        put "/api/comments/#{comment.id}/spam"
        expect(last_response.status).to eq(401)
      end

      it 'marks comment as spam when authenticated' do
        login_as(user)

        put "/api/comments/#{comment.id}/spam"

        expect(last_response).to be_ok
        expect(comment.reload.spam).to eq(true)
        expect(comment.approved).to eq(false)
      end

      it 'returns 404 for non-existent comment' do
        login_as(user)

        put '/api/comments/99999/spam'

        expect(last_response.status).to eq(404)
        data = JSON.parse(last_response.body)
        expect(data['error']).to eq('Comment not found')
      end
    end

    describe 'DELETE /api/comments/:id' do
      let(:comment) { Comment.create!(post: test_post, author_name: 'John', author_email: 'john@example.com', content: 'Test') }

      it 'requires authentication' do
        delete "/api/comments/#{comment.id}"
        expect(last_response.status).to eq(401)
      end

      it 'deletes comment when authenticated' do
        login_as(user)
        comment_id = comment.id

        delete "/api/comments/#{comment.id}"

        expect(last_response).to be_ok
        expect(Comment.find_by(id: comment_id)).to be_nil
      end

      it 'returns 404 for non-existent comment' do
        login_as(user)

        delete '/api/comments/99999'

        expect(last_response.status).to eq(404)
        data = JSON.parse(last_response.body)
        expect(data['error']).to eq('Comment not found')
      end
    end
  end
end
