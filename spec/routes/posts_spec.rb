require 'spec_helper'

RSpec.describe 'Posts API Routes' do
  let(:user) { User.create!(email: 'author@example.com', provider: 'google_oauth2', uid: '12345', name: 'Author', admin: true) }

  def login_as_user
    { 'rack.session' => { user_id: user.id } }
  end

  describe 'GET /api/posts' do
    context 'when posts exist' do
      before do
        post1 = Post.create!(title: 'Published Post', slug: 'published', content: 'Content', status: 'ready')
        post1.publish!
        Post.create!(title: 'Draft Post', slug: 'draft', content: 'Draft content', status: 'draft')
        post2 = Post.create!(title: 'Another Published', slug: 'another', content: 'More content', status: 'ready')
        post2.publish!
      end

      it 'returns all published posts by default' do
        get '/api/posts'

        expect(last_response).to be_ok
        data = JSON.parse(last_response.body)
        expect(data['posts'].length).to eq(2)
        expect(data['posts'].all? { |p| p['published'] }).to be true
      end

      it 'returns posts in reverse chronological order' do
        get '/api/posts'

        data = JSON.parse(last_response.body)
        titles = data['posts'].map { |p| p['title'] }
        expect(titles).to eq(['Another Published', 'Published Post'])
      end
    end

    context 'when logged in as admin' do
      before do
        post1 = Post.create!(title: 'Published Post', slug: 'published', content: 'Content', status: 'ready')
        post1.publish!
        Post.create!(title: 'Draft Post', slug: 'draft', content: 'Draft content', status: 'draft')
      end

      it 'can request all posts including drafts' do
        get '/api/posts', { include_drafts: 'true' }, { 'rack.session' => { user_id: user.id } }

        expect(last_response).to be_ok
        data = JSON.parse(last_response.body)
        expect(data['posts'].length).to eq(2)
      end
    end

    context 'when no posts exist' do
      it 'returns an empty array' do
        get '/api/posts'

        expect(last_response).to be_ok
        data = JSON.parse(last_response.body)
        expect(data['posts']).to eq([])
      end
    end

    describe 'pagination' do
      before do
        # Create 25 posts to test pagination
        25.times do |i|
          post = Post.create!(
            title: "Post #{i}",
            slug: "post-#{i}",
            content: 'Content',
            status: 'ready'
          )
          post.publish!
        end
      end

      it 'returns first 20 posts by default' do
        get '/api/posts'

        expect(last_response).to be_ok
        data = JSON.parse(last_response.body)

        expect(data['posts'].length).to eq(20)
        expect(data['pagination']).to include(
          'total' => 25,
          'limit' => 20,
          'offset' => 0,
          'count' => 20
        )
      end

      it 'respects custom limit parameter' do
        get '/api/posts?limit=5'

        data = JSON.parse(last_response.body)
        expect(data['posts'].length).to eq(5)
        expect(data['pagination']['limit']).to eq(5)
      end

      it 'respects offset parameter' do
        get '/api/posts?limit=5&offset=10'

        data = JSON.parse(last_response.body)
        expect(data['posts'].length).to eq(5)
        expect(data['pagination']['offset']).to eq(10)
      end

      it 'clamps limit to maximum of 100' do
        get '/api/posts?limit=500'

        data = JSON.parse(last_response.body)
        expect(data['pagination']['limit']).to eq(100)
      end

      it 'handles offset beyond total' do
        get '/api/posts?offset=999'

        data = JSON.parse(last_response.body)
        expect(data['posts']).to be_empty
        expect(data['pagination']).to include(
          'total' => 25,
          'count' => 0
        )
      end

      it 'treats invalid limit as default' do
        get '/api/posts?limit=-5'

        data = JSON.parse(last_response.body)
        expect(data['pagination']['limit']).to eq(20)
      end

      it 'treats invalid offset as zero' do
        get '/api/posts?offset=-10'

        data = JSON.parse(last_response.body)
        expect(data['pagination']['offset']).to eq(0)
      end

      it 'works with include_drafts filter' do
        Post.create!(title: 'Draft', slug: 'draft', content: 'Content', status: 'draft')

        get '/api/posts?include_drafts=true&limit=10', {}, login_as_user

        data = JSON.parse(last_response.body)
        expect(data['pagination']['total']).to eq(26)  # 25 + 1 draft
      end
    end
  end

  describe 'GET /api/posts/:id' do
    let!(:post) do
      p = Post.create!(title: 'Test Post', slug: 'test-post', content: 'Test content', status: 'ready')
      p.publish!
      p
    end

    it 'returns a specific post by id' do
      get "/api/posts/#{post.id}"

      expect(last_response).to be_ok
      data = JSON.parse(last_response.body)
      expect(data['post']['id']).to eq(post.id)
      expect(data['post']['title']).to eq('Test Post')
      expect(data['post']['slug']).to eq('test-post')
      expect(data['post']['content']).to eq('Test content')
    end

    it 'returns a post by slug' do
      get '/api/posts/test-post'

      expect(last_response).to be_ok
      data = JSON.parse(last_response.body)
      expect(data['post']['id']).to eq(post.id)
    end

    it 'returns 404 for non-existent post' do
      get '/api/posts/99999'

      expect(last_response.status).to eq(404)
      data = JSON.parse(last_response.body)
      expect(data['error']).to eq('Post not found')
    end

    it 'includes comments_enabled in response' do
      post = Post.create!(title: 'Test', slug: 'test', comments_enabled: false, status: 'ready')
      post.publish!
      get "/api/posts/#{post.id}"
      json = JSON.parse(last_response.body)
      expect(json['post']['comments_enabled']).to eq(false)
    end

    it 'includes comments_allowed computed field in response' do
      post = Post.create!(title: 'Test', slug: 'test', comments_enabled: true, status: 'ready')
      post.publish!
      Setting.instance.update!(allow_comments: false)
      get "/api/posts/#{post.id}"
      json = JSON.parse(last_response.body)
      expect(json['post']['comments_allowed']).to eq(false)
    end

    context 'with draft post' do
      let!(:draft) { Post.create!(title: 'Draft', slug: 'draft', content: 'Draft', status: 'draft') }

      it 'returns 404 for unpublished posts when not logged in' do
        get "/api/posts/#{draft.id}"

        expect(last_response.status).to eq(404)
      end

      it 'returns draft post when logged in' do
        get "/api/posts/#{draft.id}", {}, { 'rack.session' => { user_id: user.id } }

        expect(last_response).to be_ok
        data = JSON.parse(last_response.body)
        expect(data['post']['id']).to eq(draft.id)
      end
    end
  end

  describe 'POST /api/posts' do
    context 'when not logged in' do
      it 'returns 401 unauthorized' do
        post '/api/posts', { title: 'New Post', content: 'Content' }.to_json, { 'CONTENT_TYPE' => 'application/json' }

        expect(last_response.status).to eq(401)
      end
    end

    context 'when logged in' do
      it 'creates a new post' do
        expect {
          post '/api/posts',
            { title: 'New Post', content: 'New content' }.to_json,
            { 'rack.session' => { user_id: user.id }, 'CONTENT_TYPE' => 'application/json' }
        }.to change(Post, :count).by(1)

        expect(last_response.status).to eq(201)
        data = JSON.parse(last_response.body)
        expect(data['post']['title']).to eq('New Post')
        expect(data['post']['content']).to eq('New content')
        expect(data['post']['slug']).to eq('new-post')
        expect(data['post']['published']).to be false
      end

      it 'can create a published post' do
        post '/api/posts',
          { title: 'Published Post', content: 'Content', status: 'published' }.to_json,
          { 'rack.session' => { user_id: user.id }, 'CONTENT_TYPE' => 'application/json' }

        expect(last_response.status).to eq(201)
        data = JSON.parse(last_response.body)
        expect(data['post']['status']).to eq('published')
      end

      it 'can specify a custom slug' do
        post '/api/posts',
          { title: 'Custom Slug Post', slug: 'my-custom-slug', content: 'Content' }.to_json,
          { 'rack.session' => { user_id: user.id }, 'CONTENT_TYPE' => 'application/json' }

        expect(last_response.status).to eq(201)
        data = JSON.parse(last_response.body)
        expect(data['post']['slug']).to eq('my-custom-slug')
      end

      it 'returns 422 for invalid post data' do
        post '/api/posts',
          { content: 'Missing title' }.to_json,
          { 'rack.session' => { user_id: user.id }, 'CONTENT_TYPE' => 'application/json' }

        expect(last_response.status).to eq(422)
        data = JSON.parse(last_response.body)
        expect(data['errors']).to be_present
      end

      it 'returns 422 for malformed JSON' do
        post '/api/posts',
          'this is not valid JSON',
          { 'rack.session' => { user_id: user.id }, 'CONTENT_TYPE' => 'application/json' }

        expect(last_response.status).to eq(422)
        data = JSON.parse(last_response.body)
        expect(data['errors']).to include('Invalid JSON')
      end

      it 'accepts comments_enabled parameter' do
        post '/api/posts', {
          title: 'Test',
          content: 'Content',
          comments_enabled: false
        }.to_json, { 'rack.session' => { user_id: user.id }, 'CONTENT_TYPE' => 'application/json' }

        expect(last_response.status).to eq(201)
        json = JSON.parse(last_response.body)
        expect(json['post']['comments_enabled']).to eq(false)
      end
    end
  end

  describe 'PUT /api/posts/:id' do
    let!(:post) { Post.create!(title: 'Original Title', slug: 'original', content: 'Original content', status: 'draft') }

    context 'when not logged in' do
      it 'returns 401 unauthorized' do
        put "/api/posts/#{post.id}", { title: 'Updated' }.to_json, { 'CONTENT_TYPE' => 'application/json' }

        expect(last_response.status).to eq(401)
      end
    end

    context 'when logged in' do
      it 'updates the post' do
        put "/api/posts/#{post.id}",
          { title: 'Updated Title', content: 'Updated content' }.to_json,
          { 'rack.session' => { user_id: user.id }, 'CONTENT_TYPE' => 'application/json' }

        expect(last_response).to be_ok
        data = JSON.parse(last_response.body)
        expect(data['post']['title']).to eq('Updated Title')
        expect(data['post']['content']).to eq('Updated content')

        post.reload
        expect(post.title).to eq('Updated Title')
      end

      it 'can publish a draft post' do
        put "/api/posts/#{post.id}",
          { status: 'published' }.to_json,
          { 'rack.session' => { user_id: user.id }, 'CONTENT_TYPE' => 'application/json' }

        expect(last_response).to be_ok
        post.reload
        expect(post.status).to eq('published')
      end

      it 'returns 404 for non-existent post' do
        put '/api/posts/99999',
          { title: 'Updated' }.to_json,
          { 'rack.session' => { user_id: user.id }, 'CONTENT_TYPE' => 'application/json' }

        expect(last_response.status).to eq(404)
      end

      it 'returns 422 for invalid update data' do
        put "/api/posts/#{post.id}",
          { title: '' }.to_json,
          { 'rack.session' => { user_id: user.id }, 'CONTENT_TYPE' => 'application/json' }

        expect(last_response.status).to eq(422)
        data = JSON.parse(last_response.body)
        expect(data['errors']).to be_present
      end

      it 'returns 422 for malformed JSON' do
        put "/api/posts/#{post.id}",
          'invalid json content',
          { 'rack.session' => { user_id: user.id }, 'CONTENT_TYPE' => 'application/json' }

        expect(last_response.status).to eq(422)
        data = JSON.parse(last_response.body)
        expect(data['errors']).to include('Invalid JSON')
      end

      it 'accepts comments_enabled parameter' do
        post = Post.create!(title: 'Test', slug: 'test', comments_enabled: true)

        put "/api/posts/#{post.id}", {
          comments_enabled: false
        }.to_json, { 'rack.session' => { user_id: user.id }, 'CONTENT_TYPE' => 'application/json' }

        expect(last_response.status).to eq(200)
        expect(post.reload.comments_enabled).to eq(false)
      end
    end
  end

  describe 'DELETE /api/posts/:id' do
    let!(:post) { Post.create!(title: 'To Delete', slug: 'to-delete', content: 'Content', status: 'draft') }

    context 'when not logged in' do
      it 'returns 401 unauthorized' do
        delete "/api/posts/#{post.id}"

        expect(last_response.status).to eq(401)
      end
    end

    context 'when logged in' do
      it 'deletes the post' do
        expect {
          delete "/api/posts/#{post.id}", {}, { 'rack.session' => { user_id: user.id } }
        }.to change(Post, :count).by(-1)

        expect(last_response.status).to eq(204)
      end

      it 'returns 404 for non-existent post' do
        delete '/api/posts/99999', {}, { 'rack.session' => { user_id: user.id } }

        expect(last_response.status).to eq(404)
      end
    end
  end

  describe 'PUT /api/posts/:id/status' do
    let(:user) { User.create!(email: 'admin@example.com', name: 'Admin', provider: 'google', uid: '123', admin: true) }
    let(:post_record) { Post.create!(title: 'Test', slug: 'test', content: 'Content', status: 'draft') }

    it 'updates status to ready' do
      put "/api/posts/#{post_record.id}/status",
        { status: 'ready' }.to_json,
        { 'rack.session' => { user_id: user.id }, 'CONTENT_TYPE' => 'application/json', 'HTTP_X_REQUESTED_WITH' => 'XMLHttpRequest' }

      expect(last_response).to be_ok
      expect(post_record.reload.status).to eq('ready')
    end

    it 'rejects invalid status' do
      put "/api/posts/#{post_record.id}/status",
        { status: 'invalid' }.to_json,
        { 'rack.session' => { user_id: user.id }, 'CONTENT_TYPE' => 'application/json', 'HTTP_X_REQUESTED_WITH' => 'XMLHttpRequest' }

      expect(last_response.status).to eq(422)
    end

    it 'requires authentication' do
      put "/api/posts/#{post_record.id}/status",
        { status: 'ready' }.to_json,
        { 'CONTENT_TYPE' => 'application/json', 'HTTP_X_REQUESTED_WITH' => 'XMLHttpRequest' }

      expect(last_response.status).to eq(401)
    end
  end

  describe 'POST /api/posts/:id/publish' do
    let(:user) { User.create!(email: 'admin@example.com', name: 'Admin', provider: 'google', uid: '123', admin: true) }
    let(:post_record) { Post.create!(title: 'Test', slug: 'test', content: 'Content', status: 'ready') }

    it 'publishes the post' do
      post "/api/posts/#{post_record.id}/publish",
        nil,
        { 'rack.session' => { user_id: user.id }, 'HTTP_X_REQUESTED_WITH' => 'XMLHttpRequest' }

      expect(last_response).to be_ok
      post_record.reload
      expect(post_record.status).to eq('published')
      expect(post_record.published_version_id).not_to be_nil
    end

    it 'requires authentication' do
      post "/api/posts/#{post_record.id}/publish",
        nil,
        { 'HTTP_X_REQUESTED_WITH' => 'XMLHttpRequest' }

      expect(last_response.status).to eq(401)
    end
  end

  describe 'POST /api/posts/:id/unpublish' do
    let(:user) { User.create!(email: 'admin@example.com', name: 'Admin', provider: 'google', uid: '123', admin: true) }
    let(:post_record) do
      p = Post.create!(title: 'Test', slug: 'test', content: 'Content', status: 'published')
      v = p.content_versions.create!(version_number: 1, version_type: 'workflow', workflow_state: 'published', title: 'Test', content: 'Content')
      p.update_column(:published_version_id, v.id)
      p
    end

    it 'unpublishes the post' do
      post "/api/posts/#{post_record.id}/unpublish",
        nil,
        { 'rack.session' => { user_id: user.id }, 'HTTP_X_REQUESTED_WITH' => 'XMLHttpRequest' }

      expect(last_response).to be_ok
      post_record.reload
      expect(post_record.status).to eq('draft')
      expect(post_record.published_version_id).to be_nil
    end
  end

  describe 'tag support' do
    let(:tag1) { Tag.create!(name: 'Ruby', slug: 'ruby') }
    let(:tag2) { Tag.create!(name: 'Sinatra', slug: 'sinatra') }
    let(:post_record) { Post.create!(title: 'Tagged Post', slug: 'tagged-post', content: 'Content', status: 'ready') }

    describe 'GET /api/posts/:id' do
      it 'includes tags array in response' do
        post_record.tags << tag1
        post_record.tags << tag2
        post_record.publish!

        get "/api/posts/#{post_record.id}"

        expect(last_response).to be_ok
        data = JSON.parse(last_response.body)
        tags = data['post']['tags']
        expect(tags).to be_an(Array)
        expect(tags.length).to eq(2)
        tag_names = tags.map { |t| t['name'] }
        expect(tag_names).to match_array(['Ruby', 'Sinatra'])
      end

      it 'includes id, name, and slug for each tag' do
        post_record.tags << tag1
        post_record.publish!

        get "/api/posts/#{post_record.id}"

        data = JSON.parse(last_response.body)
        tag = data['post']['tags'].first
        expect(tag).to include('id', 'name', 'slug')
        expect(tag['name']).to eq('Ruby')
        expect(tag['slug']).to eq('ruby')
      end

      it 'returns empty tags array when post has no tags' do
        post_record.publish!

        get "/api/posts/#{post_record.id}"

        data = JSON.parse(last_response.body)
        expect(data['post']['tags']).to eq([])
      end
    end

    describe 'POST /api/posts' do
      it 'assigns tags via tag_ids' do
        post '/api/posts',
          { title: 'New Post', content: 'Content', tag_ids: [tag1.id, tag2.id] }.to_json,
          { 'rack.session' => { user_id: user.id }, 'CONTENT_TYPE' => 'application/json' }

        expect(last_response.status).to eq(201)
        data = JSON.parse(last_response.body)
        tag_names = data['post']['tags'].map { |t| t['name'] }
        expect(tag_names).to match_array(['Ruby', 'Sinatra'])
      end

      it 'ignores invalid tag_ids' do
        post '/api/posts',
          { title: 'New Post', content: 'Content', tag_ids: [tag1.id, 99999] }.to_json,
          { 'rack.session' => { user_id: user.id }, 'CONTENT_TYPE' => 'application/json' }

        expect(last_response.status).to eq(201)
        data = JSON.parse(last_response.body)
        expect(data['post']['tags'].length).to eq(1)
        expect(data['post']['tags'].first['name']).to eq('Ruby')
      end

      it 'creates post with no tags when tag_ids not provided' do
        post '/api/posts',
          { title: 'New Post', content: 'Content' }.to_json,
          { 'rack.session' => { user_id: user.id }, 'CONTENT_TYPE' => 'application/json' }

        expect(last_response.status).to eq(201)
        data = JSON.parse(last_response.body)
        expect(data['post']['tags']).to eq([])
      end
    end

    describe 'PUT /api/posts/:id' do
      before do
        post_record.tags << tag1
      end

      it 'replaces tags when tag_ids provided' do
        put "/api/posts/#{post_record.id}",
          { tag_ids: [tag2.id] }.to_json,
          { 'rack.session' => { user_id: user.id }, 'CONTENT_TYPE' => 'application/json' }

        expect(last_response).to be_ok
        data = JSON.parse(last_response.body)
        expect(data['post']['tags'].length).to eq(1)
        expect(data['post']['tags'].first['name']).to eq('Sinatra')
      end

      it 'clears tags when tag_ids is empty array' do
        put "/api/posts/#{post_record.id}",
          { tag_ids: [] }.to_json,
          { 'rack.session' => { user_id: user.id }, 'CONTENT_TYPE' => 'application/json' }

        expect(last_response).to be_ok
        data = JSON.parse(last_response.body)
        expect(data['post']['tags']).to eq([])
      end

      it 'does not change tags when tag_ids is not provided' do
        put "/api/posts/#{post_record.id}",
          { title: 'Updated Title' }.to_json,
          { 'rack.session' => { user_id: user.id }, 'CONTENT_TYPE' => 'application/json' }

        expect(last_response).to be_ok
        data = JSON.parse(last_response.body)
        expect(data['post']['tags'].length).to eq(1)
        expect(data['post']['tags'].first['name']).to eq('Ruby')
      end
    end
  end
end
