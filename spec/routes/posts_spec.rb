require 'spec_helper'

RSpec.describe 'Posts API Routes' do
  let(:user) { User.create!(email: 'author@example.com', provider: 'google_oauth2', uid: '12345', name: 'Author') }

  describe 'GET /api/posts' do
    context 'when posts exist' do
      before do
        Post.create!(title: 'Published Post', slug: 'published', content: 'Content', published: true)
        Post.create!(title: 'Draft Post', slug: 'draft', content: 'Draft content', published: false)
        Post.create!(title: 'Another Published', slug: 'another', content: 'More content', published: true)
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
        Post.create!(title: 'Published Post', slug: 'published', content: 'Content', published: true)
        Post.create!(title: 'Draft Post', slug: 'draft', content: 'Draft content', published: false)
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
  end

  describe 'GET /api/posts/:id' do
    let!(:post) { Post.create!(title: 'Test Post', slug: 'test-post', content: 'Test content', published: true) }

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

    context 'with draft post' do
      let!(:draft) { Post.create!(title: 'Draft', slug: 'draft', content: 'Draft', published: false) }

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
          { title: 'Published Post', content: 'Content', published: true }.to_json,
          { 'rack.session' => { user_id: user.id }, 'CONTENT_TYPE' => 'application/json' }

        expect(last_response.status).to eq(201)
        data = JSON.parse(last_response.body)
        expect(data['post']['published']).to be true
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
    end
  end

  describe 'PUT /api/posts/:id' do
    let!(:post) { Post.create!(title: 'Original Title', slug: 'original', content: 'Original content', published: false) }

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
          { published: true }.to_json,
          { 'rack.session' => { user_id: user.id }, 'CONTENT_TYPE' => 'application/json' }

        expect(last_response).to be_ok
        post.reload
        expect(post.published).to be true
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
    end
  end

  describe 'DELETE /api/posts/:id' do
    let!(:post) { Post.create!(title: 'To Delete', slug: 'to-delete', content: 'Content', published: false) }

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
end
