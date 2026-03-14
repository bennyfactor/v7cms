require 'spec_helper'

RSpec.describe 'Tags API', type: :request do
  let(:user) { User.create!(email: 'admin@example.com', provider: 'google_oauth2', uid: '12345', admin: true) }

  def login_as(user)
    env 'rack.session', { user_id: user.id }
  end

  def json_headers
    { 'CONTENT_TYPE' => 'application/json', 'HTTP_X_REQUESTED_WITH' => 'XMLHttpRequest' }
  end

  def auth_json_headers(user)
    { 'rack.session' => { user_id: user.id }, 'CONTENT_TYPE' => 'application/json', 'HTTP_X_REQUESTED_WITH' => 'XMLHttpRequest' }
  end

  describe 'GET /api/tags' do
    before do
      Tag.create!(name: 'Ruby', slug: 'ruby')
      Tag.create!(name: 'Alpine', slug: 'alpine')
      Tag.create!(name: 'Sinatra', slug: 'sinatra')
    end

    it 'returns all tags ordered by name' do
      get '/api/tags'

      expect(last_response).to be_ok
      data = JSON.parse(last_response.body)
      expect(data['tags'].length).to eq(3)
      expect(data['tags'].map { |t| t['name'] }).to eq(%w[Alpine Ruby Sinatra])
    end

    it 'includes id, name, slug, and posts_count for each tag' do
      get '/api/tags'

      data = JSON.parse(last_response.body)
      tag = data['tags'].find { |t| t['name'] == 'Ruby' }
      expect(tag).to include('id', 'name', 'slug', 'posts_count')
      expect(tag['slug']).to eq('ruby')
      expect(tag['posts_count']).to eq(0)
    end

    it 'returns correct posts_count when tag has posts' do
      ruby_tag = Tag.find_by(name: 'Ruby')
      post1 = Post.create!(title: 'Post 1', slug: 'post-1', content: 'Content', status: 'ready')
      post1.publish!
      post1.tags << ruby_tag

      get '/api/tags'

      data = JSON.parse(last_response.body)
      tag = data['tags'].find { |t| t['name'] == 'Ruby' }
      expect(tag['posts_count']).to eq(1)
    end

    it 'returns empty array when no tags exist' do
      Tag.destroy_all

      get '/api/tags'

      expect(last_response).to be_ok
      data = JSON.parse(last_response.body)
      expect(data['tags']).to eq([])
    end

    it 'is accessible without authentication' do
      get '/api/tags'
      expect(last_response.status).to eq(200)
    end
  end

  describe 'POST /api/tags' do
    context 'when not logged in' do
      it 'returns 401 unauthorized' do
        post '/api/tags', { name: 'New Tag' }.to_json, json_headers

        expect(last_response.status).to eq(401)
      end
    end

    context 'when logged in' do
      it 'creates a new tag and returns 201' do
        expect do
          post '/api/tags', { name: 'New Tag' }.to_json, auth_json_headers(user)
        end.to change(Tag, :count).by(1)

        expect(last_response.status).to eq(201)
        data = JSON.parse(last_response.body)
        expect(data['tag']['name']).to eq('New Tag')
        expect(data['tag']['slug']).to eq('new-tag')
        expect(data['tag']['posts_count']).to eq(0)
      end

      it 'auto-generates a slug from the name' do
        post '/api/tags', { name: 'Ruby on Rails' }.to_json, auth_json_headers(user)

        expect(last_response.status).to eq(201)
        data = JSON.parse(last_response.body)
        expect(data['tag']['slug']).to eq('ruby-on-rails')
      end

      it 'returns 422 for duplicate tag name' do
        Tag.create!(name: 'Duplicate', slug: 'duplicate')

        post '/api/tags', { name: 'Duplicate' }.to_json, auth_json_headers(user)

        expect(last_response.status).to eq(422)
        data = JSON.parse(last_response.body)
        expect(data['errors']).to be_present
      end

      it 'returns 422 for blank name' do
        post '/api/tags', { name: '' }.to_json, auth_json_headers(user)

        expect(last_response.status).to eq(422)
        data = JSON.parse(last_response.body)
        expect(data['errors']).to be_present
      end

      it 'returns 422 for invalid JSON' do
        post '/api/tags', 'not valid json', json_headers.merge('rack.session' => { user_id: user.id })

        expect(last_response.status).to eq(422)
        data = JSON.parse(last_response.body)
        expect(data['errors']).to include('Invalid JSON')
      end
    end
  end

  describe 'PUT /api/tags/:id' do
    let!(:tag) { Tag.create!(name: 'Original Name', slug: 'original-name') }

    context 'when not logged in' do
      it 'returns 401 unauthorized' do
        put "/api/tags/#{tag.id}", { name: 'Updated' }.to_json, json_headers

        expect(last_response.status).to eq(401)
      end
    end

    context 'when logged in' do
      it 'renames the tag' do
        put "/api/tags/#{tag.id}", { name: 'Updated Name' }.to_json, auth_json_headers(user)

        expect(last_response).to be_ok
        data = JSON.parse(last_response.body)
        expect(data['tag']['name']).to eq('Updated Name')

        tag.reload
        expect(tag.name).to eq('Updated Name')
      end

      it 'preserves the original slug when renaming' do
        put "/api/tags/#{tag.id}", { name: 'Updated Name' }.to_json, auth_json_headers(user)

        expect(last_response).to be_ok
        data = JSON.parse(last_response.body)
        # Slug should not be regenerated on update (only on create)
        expect(data['tag']['slug']).to eq('original-name')
      end

      it 'returns 404 for non-existent tag' do
        put '/api/tags/99999', { name: 'Updated' }.to_json, auth_json_headers(user)

        expect(last_response.status).to eq(404)
        data = JSON.parse(last_response.body)
        expect(data['error']).to eq('Tag not found')
      end

      it 'returns 422 for invalid JSON' do
        put "/api/tags/#{tag.id}", 'invalid json', json_headers.merge('rack.session' => { user_id: user.id })

        expect(last_response.status).to eq(422)
        data = JSON.parse(last_response.body)
        expect(data['errors']).to include('Invalid JSON')
      end

      it 'returns 422 for blank name' do
        put "/api/tags/#{tag.id}", { name: '' }.to_json, auth_json_headers(user)

        expect(last_response.status).to eq(422)
        data = JSON.parse(last_response.body)
        expect(data['errors']).to be_present
      end
    end
  end

  describe 'DELETE /api/tags/:id' do
    let!(:tag) { Tag.create!(name: 'Delete Me', slug: 'delete-me') }

    context 'when not logged in' do
      it 'returns 401 unauthorized' do
        delete "/api/tags/#{tag.id}", {}, { 'HTTP_X_REQUESTED_WITH' => 'XMLHttpRequest' }

        expect(last_response.status).to eq(401)
      end
    end

    context 'when logged in' do
      it 'deletes a tag with no posts and returns 204' do
        login_as(user)

        expect do
          delete "/api/tags/#{tag.id}", {}, { 'HTTP_X_REQUESTED_WITH' => 'XMLHttpRequest' }
        end.to change(Tag, :count).by(-1)

        expect(last_response.status).to eq(204)
        expect(Tag.find_by(id: tag.id)).to be_nil
      end

      it 'returns 409 when tag has associated posts' do
        login_as(user)
        post_record = Post.create!(title: 'Tagged Post', slug: 'tagged-post', content: 'Content', status: 'ready')
        post_record.publish!
        post_record.tags << tag

        delete "/api/tags/#{tag.id}", {}, { 'HTTP_X_REQUESTED_WITH' => 'XMLHttpRequest' }

        expect(last_response.status).to eq(409)
        data = JSON.parse(last_response.body)
        expect(data['error']).to include('Cannot delete tag')
      end

      it 'nullifies content_filter_tag_id on pages before deleting' do
        login_as(user)
        page = Page.create!(title: 'Filtered Page', slug: 'filtered-page', content_filter_tag_id: tag.id)

        delete "/api/tags/#{tag.id}", {}, { 'HTTP_X_REQUESTED_WITH' => 'XMLHttpRequest' }

        expect(last_response.status).to eq(204)
        page.reload
        expect(page.content_filter_tag_id).to be_nil
      end

      it 'returns 404 for non-existent tag' do
        login_as(user)

        delete '/api/tags/99999', {}, { 'HTTP_X_REQUESTED_WITH' => 'XMLHttpRequest' }

        expect(last_response.status).to eq(404)
        data = JSON.parse(last_response.body)
        expect(data['error']).to eq('Tag not found')
      end
    end
  end
end
