require_relative '../spec_helper'

RSpec.describe 'Pages API', type: :request do
  let(:user) { User.create!(email: 'test@example.com', name: 'Test User', provider: 'google_oauth2', uid: '12345', admin: true) }

  def app
    CMS
  end

  def login_as(user)
    env 'rack.session', { user_id: user.id }
  end

  describe 'GET /api/pages' do
    before do
      @published1 = Page.create!(title: 'About', slug: 'about', published: true, position: 1)
      @published2 = Page.create!(title: 'Contact', slug: 'contact', published: true, position: 2)
      @draft = Page.create!(title: 'Draft', slug: 'draft', published: false, position: 3)
      @parent = Page.create!(title: 'Services', slug: 'services', published: true, position: 4)
      @child = Page.create!(title: 'Web Dev', slug: 'web-dev', published: true, parent: @parent, position: 1)
    end

    it 'returns only published pages when not logged in' do
      get '/api/pages'
      expect(last_response).to be_ok

      data = JSON.parse(last_response.body)
      expect(data['pages'].length).to eq(4)
      expect(data['pages'].map { |p| p['slug'] }).to match_array(['about', 'contact', 'services', 'web-dev'])
    end

    it 'returns pages sorted by position and title' do
      get '/api/pages'
      expect(last_response).to be_ok

      data = JSON.parse(last_response.body)
      expect(data['pages'].first['slug']).to eq('about')  # position 1
      expect(data['pages'].second['slug']).to eq('web-dev')  # position 1 (child)
    end

    it 'includes drafts when logged in with include_drafts=true' do
      login_as(user)
      get '/api/pages?include_drafts=true'
      expect(last_response).to be_ok

      data = JSON.parse(last_response.body)
      expect(data['pages'].length).to eq(5)
      expect(data['pages'].map { |p| p['slug'] }).to include('draft')
    end

    it 'filters by parent_id when specified' do
      get "/api/pages?parent_id=#{@parent.id}"
      expect(last_response).to be_ok

      data = JSON.parse(last_response.body)
      expect(data['pages'].length).to eq(1)
      expect(data['pages'].first['slug']).to eq('web-dev')
    end

    it 'filters top-level pages when top_level=true' do
      get '/api/pages?top_level=true'
      expect(last_response).to be_ok

      data = JSON.parse(last_response.body)
      expect(data['pages'].length).to eq(3)
      expect(data['pages'].map { |p| p['slug'] }).to match_array(['about', 'contact', 'services'])
    end

    describe 'pagination' do
      before do
        # Create 25 pages to test pagination
        25.times do |i|
          Page.create!(
            title: "Page #{i}",
            slug: "page-#{i}",
            content: 'Content',
            published: true
          )
        end
      end

      it 'returns first 20 pages by default' do
        get '/api/pages'

        expect(last_response).to be_ok
        data = JSON.parse(last_response.body)

        expect(data['pages'].length).to eq(20)
        expect(data['pagination']).to include(
          'total' => 29,  # 4 from outer before + 25 from this before
          'limit' => 20,
          'offset' => 0,
          'count' => 20
        )
      end

      it 'respects custom limit parameter' do
        get '/api/pages?limit=5'

        data = JSON.parse(last_response.body)
        expect(data['pages'].length).to eq(5)
        expect(data['pagination']['limit']).to eq(5)
      end

      it 'respects offset parameter' do
        get '/api/pages?limit=5&offset=10'

        data = JSON.parse(last_response.body)
        expect(data['pages'].length).to eq(5)
        expect(data['pagination']['offset']).to eq(10)
      end

      it 'works with top_level filter' do
        parent = Page.create!(title: 'Parent', slug: 'parent', published: true)
        Page.create!(title: 'Child', slug: 'child', parent: parent, published: true)

        get '/api/pages?top_level=true&limit=10'

        data = JSON.parse(last_response.body)
        expect(data['pagination']['total']).to eq(29)  # 4 top-level from outer + 25 from this before (child not counted)
      end

      it 'works with include_drafts filter' do
        Page.create!(title: 'Draft Page', slug: 'draft-page', content: 'Content', published: false)

        login_as(user)
        get '/api/pages?include_drafts=true&limit=10'

        data = JSON.parse(last_response.body)
        expect(data['pagination']['total']).to eq(31)  # 29 published + 1 draft from outer + 1 from this test
      end
    end
  end

  describe 'GET /api/pages/:id' do
    before do
      @page = Page.create!(title: 'About', slug: 'about', content: 'About us', published: true)
      @draft = Page.create!(title: 'Draft', slug: 'draft', content: 'Draft content', published: false)
    end

    it 'returns a published page by ID' do
      get "/api/pages/#{@page.id}"
      expect(last_response).to be_ok

      data = JSON.parse(last_response.body)
      expect(data['page']['title']).to eq('About')
      expect(data['page']['content']).to eq('About us')
    end

    it 'returns a page by slug' do
      get '/api/pages/about'
      expect(last_response).to be_ok

      data = JSON.parse(last_response.body)
      expect(data['page']['title']).to eq('About')
    end

    it 'returns 404 for non-existent page' do
      get '/api/pages/999'
      expect(last_response.status).to eq(404)
    end

    it 'returns 404 for draft page when not logged in' do
      get "/api/pages/#{@draft.id}"
      expect(last_response.status).to eq(404)
    end

    it 'returns draft page when logged in' do
      login_as(user)
      get "/api/pages/#{@draft.id}"
      expect(last_response).to be_ok

      data = JSON.parse(last_response.body)
      expect(data['page']['title']).to eq('Draft')
    end

    it 'includes relations when requested' do
      parent = Page.create!(title: 'Parent', slug: 'parent', published: true)
      child = Page.create!(title: 'Child', slug: 'child', published: true, parent: parent)

      get "/api/pages/#{child.id}"
      expect(last_response).to be_ok

      data = JSON.parse(last_response.body)
      expect(data['page']['depth']).to eq(1)
      expect(data['page']['has_children']).to be false
      expect(data['page']['parent']).to be_present
      expect(data['page']['parent']['slug']).to eq('parent')
      expect(data['page']['breadcrumb_trail']).to be_an(Array)
      expect(data['page']['breadcrumb_trail'].length).to eq(2)
    end
  end

  describe 'POST /api/pages' do
    it 'requires authentication' do
      post '/api/pages', {}.to_json, { 'CONTENT_TYPE' => 'application/json', 'HTTP_X_REQUESTED_WITH' => 'XMLHttpRequest' }
      expect(last_response.status).to eq(401)
    end

    it 'creates a new page when logged in' do
      login_as(user)

      page_data = {
        title: 'New Page',
        content: 'Page content',
        published: true
      }

      post '/api/pages', page_data.to_json, { 'CONTENT_TYPE' => 'application/json', 'HTTP_X_REQUESTED_WITH' => 'XMLHttpRequest' }
      expect(last_response.status).to eq(201)

      data = JSON.parse(last_response.body)
      expect(data['page']['title']).to eq('New Page')
      expect(data['page']['slug']).to eq('new-page')
      expect(data['page']['content']).to eq('Page content')

      # Verify in database
      page = Page.find_by(slug: 'new-page')
      expect(page).to be_present
      expect(page.title).to eq('New Page')
    end

    it 'creates a page with custom slug' do
      login_as(user)

      page_data = {
        title: 'New Page',
        slug: 'custom-slug',
        content: 'Content'
      }

      post '/api/pages', page_data.to_json, { 'CONTENT_TYPE' => 'application/json', 'HTTP_X_REQUESTED_WITH' => 'XMLHttpRequest' }
      expect(last_response.status).to eq(201)

      data = JSON.parse(last_response.body)
      expect(data['page']['slug']).to eq('custom-slug')
    end

    it 'creates a page with parent' do
      login_as(user)
      parent = Page.create!(title: 'Parent', slug: 'parent', published: true)

      page_data = {
        title: 'Child Page',
        content: 'Child content',
        parent_id: parent.id
      }

      post '/api/pages', page_data.to_json, { 'CONTENT_TYPE' => 'application/json', 'HTTP_X_REQUESTED_WITH' => 'XMLHttpRequest' }
      expect(last_response.status).to eq(201)

      data = JSON.parse(last_response.body)
      expect(data['page']['parent_id']).to eq(parent.id)
      expect(data['page']['depth']).to eq(1)
    end

    it 'returns errors for invalid page' do
      login_as(user)

      page_data = {
        content: 'Content without title'
      }

      post '/api/pages', page_data.to_json, { 'CONTENT_TYPE' => 'application/json', 'HTTP_X_REQUESTED_WITH' => 'XMLHttpRequest' }
      expect(last_response.status).to eq(422)

      data = JSON.parse(last_response.body)
      expect(data['errors']).to be_an(Array)
    end

    it 'returns error for invalid JSON' do
      login_as(user)

      post '/api/pages', 'invalid json', { 'CONTENT_TYPE' => 'application/json', 'HTTP_X_REQUESTED_WITH' => 'XMLHttpRequest' }
      expect(last_response.status).to eq(422)

      data = JSON.parse(last_response.body)
      expect(data['errors']).to include('Invalid JSON')
    end
  end

  describe 'PUT /api/pages/:id' do
    before do
      @page = Page.create!(title: 'Original', slug: 'original', content: 'Original content', published: false)
    end

    it 'requires authentication' do
      put "/api/pages/#{@page.id}", {}.to_json, { 'CONTENT_TYPE' => 'application/json', 'HTTP_X_REQUESTED_WITH' => 'XMLHttpRequest' }
      expect(last_response.status).to eq(401)
    end

    it 'updates a page when logged in' do
      login_as(user)

      update_data = {
        title: 'Updated Title',
        published: true
      }

      put "/api/pages/#{@page.id}", update_data.to_json, { 'CONTENT_TYPE' => 'application/json', 'HTTP_X_REQUESTED_WITH' => 'XMLHttpRequest' }
      expect(last_response).to be_ok

      data = JSON.parse(last_response.body)
      expect(data['page']['title']).to eq('Updated Title')
      expect(data['page']['published']).to be true

      # Verify in database
      @page.reload
      expect(@page.title).to eq('Updated Title')
      expect(@page.published).to be true
    end

    it 'updates parent_id and position' do
      login_as(user)
      parent = Page.create!(title: 'Parent', slug: 'parent', published: true)

      update_data = {
        parent_id: parent.id,
        position: 5
      }

      put "/api/pages/#{@page.id}", update_data.to_json, { 'CONTENT_TYPE' => 'application/json', 'HTTP_X_REQUESTED_WITH' => 'XMLHttpRequest' }
      expect(last_response).to be_ok

      data = JSON.parse(last_response.body)
      expect(data['page']['parent_id']).to eq(parent.id)
      expect(data['page']['position']).to eq(5)
    end

    it 'returns 404 for non-existent page' do
      login_as(user)

      put '/api/pages/999', {}.to_json, { 'CONTENT_TYPE' => 'application/json', 'HTTP_X_REQUESTED_WITH' => 'XMLHttpRequest' }
      expect(last_response.status).to eq(404)
    end

    it 'returns errors for invalid update' do
      login_as(user)

      update_data = {
        slug: 'Invalid Slug!'  # Invalid format
      }

      put "/api/pages/#{@page.id}", update_data.to_json, { 'CONTENT_TYPE' => 'application/json', 'HTTP_X_REQUESTED_WITH' => 'XMLHttpRequest' }
      expect(last_response.status).to eq(422)

      data = JSON.parse(last_response.body)
      expect(data['errors']).to be_an(Array)
    end
  end

  describe 'DELETE /api/pages/:id' do
    before do
      @page = Page.create!(title: 'To Delete', slug: 'to-delete', published: false)
    end

    it 'requires authentication' do
      delete "/api/pages/#{@page.id}", {}, { 'HTTP_X_REQUESTED_WITH' => 'XMLHttpRequest' }
      expect(last_response.status).to eq(401)
    end

    it 'deletes a page when logged in' do
      login_as(user)

      delete "/api/pages/#{@page.id}", {}, { 'HTTP_X_REQUESTED_WITH' => 'XMLHttpRequest' }
      expect(last_response.status).to eq(204)

      # Verify in database
      expect(Page.find_by(id: @page.id)).to be_nil
    end

    it 'deletes children when parent is deleted' do
      login_as(user)
      parent = Page.create!(title: 'Parent', slug: 'parent', published: true)
      child = Page.create!(title: 'Child', slug: 'child', published: true, parent: parent)

      delete "/api/pages/#{parent.id}", {}, { 'HTTP_X_REQUESTED_WITH' => 'XMLHttpRequest' }
      expect(last_response.status).to eq(204)

      # Verify both parent and child are deleted
      expect(Page.find_by(id: parent.id)).to be_nil
      expect(Page.find_by(id: child.id)).to be_nil
    end

    it 'returns 404 for non-existent page' do
      login_as(user)

      delete '/api/pages/999', {}, { 'HTTP_X_REQUESTED_WITH' => 'XMLHttpRequest' }
      expect(last_response.status).to eq(404)
    end
  end

  describe 'dynamic page types' do
    let!(:parent_page) do
      Page.create!(
        title: 'Blog Section',
        slug: 'blog-section',
        published: true,
        page_type: 'blog_grid',
        content_source: 'children',
        items_limit: 10
      )
    end
    let!(:child1) { Page.create!(title: 'Article 1', slug: 'article-1', published: true, parent: parent_page) }
    let!(:child2) { Page.create!(title: 'Article 2', slug: 'article-2', published: true, parent: parent_page) }

    it 'renders layout template for layout-based page types' do
      get '/pages/blog-section'
      expect(last_response.status).to eq(200)
      expect(last_response.body).to include('Article 1')
      expect(last_response.body).to include('Article 2')
    end

    it 'renders posts when content_source is posts' do
      Post.create!(title: 'Test Post', slug: 'test-post', published: true, content: 'Post content here')
      parent_page.update!(content_source: 'posts')
      get '/pages/blog-section'
      expect(last_response.status).to eq(200)
      expect(last_response.body).to include('Test Post')
    end

    it 'continues to render standard pages with page.erb' do
      standard_page = Page.create!(title: 'About', slug: 'about', published: true, page_type: 'standard', content: '<p>About us</p>')
      get '/pages/about'
      expect(last_response.status).to eq(200)
      expect(last_response.body).to include('About us')
    end
  end

  describe 'GET /api/pages/types' do
    it 'returns available page types' do
      get '/api/pages/types'
      expect(last_response.status).to eq(200)
      json = JSON.parse(last_response.body)
      expect(json['types']).to include(
        hash_including('name' => 'standard', 'category' => 'static'),
        hash_including('name' => 'blog_grid', 'category' => 'layout')
      )
    end
  end

  describe 'API dynamic content fields' do
    it 'includes content_source and items_limit in GET /api/pages/:id response' do
      page = Page.create!(title: 'Test', slug: 'test', published: true)
      get '/api/pages/test'

      expect(last_response).to be_ok
      json = JSON.parse(last_response.body)
      expect(json['page']['content_source']).to eq('children')
      expect(json['page']['items_limit']).to eq(10)
    end

    it 'allows setting content_source on POST /api/pages create' do
      login_as(user)

      post '/api/pages', { title: 'Test', content_source: 'posts' }.to_json, { 'CONTENT_TYPE' => 'application/json', 'HTTP_X_REQUESTED_WITH' => 'XMLHttpRequest' }

      expect(last_response.status).to eq(201)
      json = JSON.parse(last_response.body)
      expect(json['page']['content_source']).to eq('posts')
    end

    it 'allows setting items_limit on POST /api/pages create' do
      login_as(user)

      post '/api/pages', { title: 'Test', items_limit: 5 }.to_json, { 'CONTENT_TYPE' => 'application/json', 'HTTP_X_REQUESTED_WITH' => 'XMLHttpRequest' }

      expect(last_response.status).to eq(201)
      json = JSON.parse(last_response.body)
      expect(json['page']['items_limit']).to eq(5)
    end

    it 'allows updating content_source via PUT /api/pages/:id' do
      login_as(user)
      page = Page.create!(title: 'Test', slug: 'test')

      put "/api/pages/#{page.id}", { content_source: 'posts' }.to_json, { 'CONTENT_TYPE' => 'application/json', 'HTTP_X_REQUESTED_WITH' => 'XMLHttpRequest' }

      expect(last_response.status).to eq(200)
      json = JSON.parse(last_response.body)
      expect(json['page']['content_source']).to eq('posts')
    end

    it 'allows updating items_limit via PUT /api/pages/:id' do
      login_as(user)
      page = Page.create!(title: 'Test', slug: 'test')

      put "/api/pages/#{page.id}", { items_limit: 15 }.to_json, { 'CONTENT_TYPE' => 'application/json', 'HTTP_X_REQUESTED_WITH' => 'XMLHttpRequest' }

      expect(last_response.status).to eq(200)
      json = JSON.parse(last_response.body)
      expect(json['page']['items_limit']).to eq(15)
    end

    it 'allows updating both content_source and items_limit together' do
      login_as(user)
      page = Page.create!(title: 'Test', slug: 'test')

      put "/api/pages/#{page.id}", { content_source: 'posts', items_limit: 5 }.to_json, { 'CONTENT_TYPE' => 'application/json', 'HTTP_X_REQUESTED_WITH' => 'XMLHttpRequest' }

      expect(last_response.status).to eq(200)
      json = JSON.parse(last_response.body)
      expect(json['page']['content_source']).to eq('posts')
      expect(json['page']['items_limit']).to eq(5)
    end
  end
end
