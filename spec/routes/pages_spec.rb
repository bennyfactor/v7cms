require_relative '../spec_helper'

RSpec.describe 'Pages API', type: :request do
  let(:user) { User.create!(email: 'test@example.com', name: 'Test User', provider: 'google_oauth2', uid: '12345', admin: true) }

  def app
    CMS
  end

  def login_as(user)
    env 'rack.session', { user_id: user.id }
  end

  def collect_nested_slugs(pages)
    pages.flat_map do |page|
      [page['slug']] + collect_nested_slugs(page['children'] || [])
    end
  end

  describe 'GET /pages/* hierarchical routing' do
    before do
      @parent = Page.create!(title: 'Services', slug: 'services')
      @parent.publish!
      @child = Page.create!(title: 'Web Dev', slug: 'web-dev', parent: @parent)
      @child.publish!
    end

    it 'resolves page by full_slug_path' do
      get '/pages/services/web-dev'
      expect(last_response).to be_ok
      expect(last_response.body).to include('Web Dev')
    end

    it 'resolves top-level page by slug' do
      get '/pages/services'
      expect(last_response).to be_ok
      expect(last_response.body).to include('Services')
    end

    it 'resolves unique leaf slug without full path' do
      get '/pages/web-dev'
      expect(last_response).to be_ok
      expect(last_response.body).to include('Web Dev')
    end

    it 'returns 404 for non-existent page' do
      get '/pages/nonexistent'
      expect(last_response.status).to eq(404)
    end
  end

  describe 'GET /* vanity page routes' do
    before do
      @page = Page.create!(title: 'About', slug: 'about')
      @page.publish!
      @parent = Page.create!(title: 'Services', slug: 'services')
      @parent.publish!
      @child = Page.create!(title: 'Consulting', slug: 'consulting', parent: @parent)
      @child.publish!
    end

    it 'serves top-level page at vanity URL' do
      get '/about'
      expect(last_response).to be_ok
      expect(last_response.body).to include('About')
    end

    it 'serves nested page at vanity URL' do
      get '/services/consulting'
      expect(last_response).to be_ok
      expect(last_response.body).to include('Consulting')
    end

    it 'does not override existing app routes' do
      get '/api/version'
      expect(last_response).to be_ok
    end

    it 'returns 404 for non-existent vanity URL' do
      get '/nonexistent-page'
      expect(last_response.status).to eq(404)
    end

    it 'does not interfere with API routes' do
      get '/api/pages'
      expect(last_response).to be_ok
      data = JSON.parse(last_response.body)
      expect(data).to have_key('pages')
    end
  end

  describe 'GET /api/pages' do
    before do
      @published1 = Page.create!(title: 'About', slug: 'about', position: 1)
      @published1.publish!
      @published2 = Page.create!(title: 'Contact', slug: 'contact', position: 2)
      @published2.publish!
      @draft = Page.create!(title: 'Draft', slug: 'draft', status: 'draft', position: 3)
      @parent = Page.create!(title: 'Services', slug: 'services', position: 4)
      @parent.publish!
      @child = Page.create!(title: 'Web Dev', slug: 'web-dev', parent: @parent, position: 1)
      @child.publish!
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

    describe 'nested=true' do
      it 'returns hierarchical structure with children nested under parents' do
        login_as(user)
        get '/api/pages?include_drafts=true&nested=true'
        expect(last_response).to be_ok

        data = JSON.parse(last_response.body)
        # Should only return top-level pages at root (including draft)
        top_slugs = data['pages'].map { |p| p['slug'] }
        expect(top_slugs).to include('about', 'contact', 'services', 'draft')
        expect(top_slugs).not_to include('web-dev')

        # web-dev should be nested under services
        services = data['pages'].find { |p| p['slug'] == 'services' }
        expect(services['children'].length).to eq(1)
        expect(services['children'].first['slug']).to eq('web-dev')
      end

      it 'includes depth values at each level' do
        login_as(user)
        get '/api/pages?include_drafts=true&nested=true'

        data = JSON.parse(last_response.body)
        # Top-level pages have depth 0
        data['pages'].each do |page|
          expect(page['depth']).to eq(0)
        end

        # Child pages have depth 1
        services = data['pages'].find { |p| p['slug'] == 'services' }
        services['children'].each do |child|
          expect(child['depth']).to eq(1)
        end
      end

      it 'handles deeply nested pages' do
        login_as(user)
        grandchild = Page.create!(title: 'Ruby Dev', slug: 'ruby-dev', parent: @child, position: 1)
        grandchild.publish!

        get '/api/pages?include_drafts=true&nested=true'

        data = JSON.parse(last_response.body)
        services = data['pages'].find { |p| p['slug'] == 'services' }
        web_dev = services['children'].find { |c| c['slug'] == 'web-dev' }
        expect(web_dev['children'].length).to eq(1)
        expect(web_dev['children'].first['slug']).to eq('ruby-dev')
        expect(web_dev['children'].first['depth']).to eq(2)
      end

      it 'returns only published nested pages when not logged in' do
        get '/api/pages?nested=true'
        expect(last_response).to be_ok

        data = JSON.parse(last_response.body)
        # Draft page should not appear
        all_slugs = collect_nested_slugs(data['pages'])
        expect(all_slugs).not_to include('draft')
      end

      it 'does not include pagination metadata' do
        get '/api/pages?nested=true'

        data = JSON.parse(last_response.body)
        expect(data).not_to have_key('pagination')
      end
    end

    describe 'pagination' do
      before do
        # Create 25 pages to test pagination
        25.times do |i|
          page = Page.create!(
            title: "Page #{i}",
            slug: "page-#{i}",
            content: 'Content'
          )
          page.publish!
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
        parent = Page.create!(title: 'Parent', slug: 'parent')
        parent.publish!
        child = Page.create!(title: 'Child', slug: 'child', parent: parent)
        child.publish!

        get '/api/pages?top_level=true&limit=10'

        data = JSON.parse(last_response.body)
        expect(data['pagination']['total']).to eq(29)  # 4 top-level from outer + 25 from this before (child not counted)
      end

      it 'works with include_drafts filter' do
        Page.create!(title: 'Draft Page', slug: 'draft-page', content: 'Content', status: 'draft')

        login_as(user)
        get '/api/pages?include_drafts=true&limit=10'

        data = JSON.parse(last_response.body)
        expect(data['pagination']['total']).to eq(31)  # 29 published + 1 draft from outer + 1 from this test
      end
    end
  end

  describe 'GET /api/pages/:id' do
    before do
      @page = Page.create!(title: 'About', slug: 'about', content: 'About us')
      @page.publish!
      @draft = Page.create!(title: 'Draft', slug: 'draft', content: 'Draft content', status: 'draft')
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
      parent = Page.create!(title: 'Parent', slug: 'parent')
      parent.publish!
      child = Page.create!(title: 'Child', slug: 'child', parent: parent)
      child.publish!

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

    it 'includes hero_image_url in page response' do
      page = Page.create!(title: 'Test', slug: 'test-hero', hero_image_url: 'https://example.com/hero.jpg')
      page.publish!
      get "/api/pages/#{page.id}"

      expect(last_response).to be_ok
      data = JSON.parse(last_response.body)
      expect(data['page']['hero_image_url']).to eq('https://example.com/hero.jpg')
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
        status: 'draft'
      }

      post '/api/pages', page_data.to_json, { 'CONTENT_TYPE' => 'application/json', 'HTTP_X_REQUESTED_WITH' => 'XMLHttpRequest' }
      expect(last_response.status).to eq(201)

      data = JSON.parse(last_response.body)
      expect(data['page']['title']).to eq('New Page')
      expect(data['page']['slug']).to eq('new-page')
      expect(data['page']['content']).to eq('Page content')
      expect(data['page']['status']).to eq('draft')

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
      parent = Page.create!(title: 'Parent', slug: 'parent')

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
      @page = Page.create!(title: 'Original', slug: 'original', content: 'Original content', status: 'draft')
    end

    it 'requires authentication' do
      put "/api/pages/#{@page.id}", {}.to_json, { 'CONTENT_TYPE' => 'application/json', 'HTTP_X_REQUESTED_WITH' => 'XMLHttpRequest' }
      expect(last_response.status).to eq(401)
    end

    it 'updates a page when logged in' do
      login_as(user)
      @page.publish!

      update_data = {
        title: 'Updated Title'
      }

      put "/api/pages/#{@page.id}", update_data.to_json, { 'CONTENT_TYPE' => 'application/json', 'HTTP_X_REQUESTED_WITH' => 'XMLHttpRequest' }
      expect(last_response).to be_ok

      data = JSON.parse(last_response.body)
      expect(data['page']['title']).to eq('Updated Title')
      # NOTE: Page should auto-flip to draft on content change
      expect(data['page']['status']).to eq('draft')

      # Verify in database
      @page.reload
      expect(@page.title).to eq('Updated Title')
      expect(@page.status).to eq('draft')
    end

    it 'updates parent_id and position' do
      login_as(user)
      parent = Page.create!(title: 'Parent', slug: 'parent')

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
      @page = Page.create!(title: 'To Delete', slug: 'to-delete', status: 'draft')
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
      parent = Page.create!(title: 'Parent', slug: 'parent')
      child = Page.create!(title: 'Child', slug: 'child', parent: parent)

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
      page = Page.create!(
        title: 'Blog Section',
        slug: 'blog-section',
        page_type: 'blog_grid',
        content_source: 'children',
        items_limit: 10
      )
      page.publish!
      page
    end
    let!(:child1) do
      child = Page.create!(title: 'Article 1', slug: 'article-1', parent: parent_page)
      child.publish!
      child
    end
    let!(:child2) do
      child = Page.create!(title: 'Article 2', slug: 'article-2', parent: parent_page)
      child.publish!
      child
    end

    it 'renders layout template for layout-based page types' do
      get '/pages/blog-section'
      expect(last_response.status).to eq(200)
      expect(last_response.body).to include('Article 1')
      expect(last_response.body).to include('Article 2')
    end

    it 'renders posts when content_source is posts' do
      post = Post.create!(title: 'Test Post', slug: 'test-post', content: 'Post content here')
      post.publish!
      parent_page.update!(content_source: 'posts')
      get '/pages/blog-section'
      expect(last_response.status).to eq(200)
      expect(last_response.body).to include('Test Post')
    end

    it 'continues to render standard pages with page.erb' do
      standard_page = Page.create!(title: 'About', slug: 'about', page_type: 'standard', content: '<p>About us</p>')
      standard_page.publish!
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
      page = Page.create!(title: 'Test', slug: 'test')
      page.publish!
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

  describe 'PUT /api/pages/:id/status' do
    it 'requires authentication' do
      page = Page.create!(title: 'Test', slug: 'test')

      put "/api/pages/#{page.id}/status", { status: 'published' }.to_json,
          { 'CONTENT_TYPE' => 'application/json', 'HTTP_X_REQUESTED_WITH' => 'XMLHttpRequest' }

      expect(last_response.status).to eq(401)
    end

    it 'updates page status when logged in' do
      login_as(user)
      page = Page.create!(title: 'Test', slug: 'test', status: 'draft')

      put "/api/pages/#{page.id}/status", { status: 'ready' }.to_json,
          { 'CONTENT_TYPE' => 'application/json', 'HTTP_X_REQUESTED_WITH' => 'XMLHttpRequest' }

      expect(last_response).to be_ok
      data = JSON.parse(last_response.body)
      expect(data['page']['status']).to eq('ready')

      page.reload
      expect(page.status).to eq('ready')
    end

    it 'returns 422 for invalid status' do
      login_as(user)
      page = Page.create!(title: 'Test', slug: 'test')

      put "/api/pages/#{page.id}/status", { status: 'invalid' }.to_json,
          { 'CONTENT_TYPE' => 'application/json', 'HTTP_X_REQUESTED_WITH' => 'XMLHttpRequest' }

      expect(last_response.status).to eq(422)
      data = JSON.parse(last_response.body)
      expect(data['errors']).to include('Invalid status. Must be one of: draft, ready, published')
    end

    it 'returns 404 for non-existent page' do
      login_as(user)

      put '/api/pages/99999/status', { status: 'published' }.to_json,
          { 'CONTENT_TYPE' => 'application/json', 'HTTP_X_REQUESTED_WITH' => 'XMLHttpRequest' }

      expect(last_response.status).to eq(404)
    end
  end

  describe 'POST /api/pages/:id/publish' do
    it 'requires authentication' do
      page = Page.create!(title: 'Test', slug: 'test')

      post "/api/pages/#{page.id}/publish", {},
           { 'CONTENT_TYPE' => 'application/json', 'HTTP_X_REQUESTED_WITH' => 'XMLHttpRequest' }

      expect(last_response.status).to eq(401)
    end

    it 'publishes a page when logged in' do
      login_as(user)
      page = Page.create!(title: 'Test', slug: 'test', content: 'Content', status: 'draft')

      post "/api/pages/#{page.id}/publish", {},
           { 'CONTENT_TYPE' => 'application/json', 'HTTP_X_REQUESTED_WITH' => 'XMLHttpRequest' }

      expect(last_response).to be_ok
      data = JSON.parse(last_response.body)
      expect(data['page']['status']).to eq('published')
      expect(data['page']['published']).to be true
      expect(data['page']['published_version_id']).not_to be_nil

      page.reload
      expect(page.status).to eq('published')
      expect(page.published_version_id).not_to be_nil
    end

    it 'returns 404 for non-existent page' do
      login_as(user)

      post '/api/pages/99999/publish', {},
           { 'CONTENT_TYPE' => 'application/json', 'HTTP_X_REQUESTED_WITH' => 'XMLHttpRequest' }

      expect(last_response.status).to eq(404)
    end
  end

  describe 'POST /api/pages/:id/unpublish' do
    it 'requires authentication' do
      page = Page.create!(title: 'Test', slug: 'test')
      page.publish!

      post "/api/pages/#{page.id}/unpublish", {},
           { 'CONTENT_TYPE' => 'application/json', 'HTTP_X_REQUESTED_WITH' => 'XMLHttpRequest' }

      expect(last_response.status).to eq(401)
    end

    it 'unpublishes a page when logged in' do
      login_as(user)
      page = Page.create!(title: 'Test', slug: 'test', content: 'Content', status: 'draft')
      page.publish!

      post "/api/pages/#{page.id}/unpublish", {},
           { 'CONTENT_TYPE' => 'application/json', 'HTTP_X_REQUESTED_WITH' => 'XMLHttpRequest' }

      expect(last_response).to be_ok
      data = JSON.parse(last_response.body)
      expect(data['page']['status']).to eq('draft')
      expect(data['page']['published']).to be false
      expect(data['page']['published_version_id']).to be_nil

      page.reload
      expect(page.status).to eq('draft')
      expect(page.published_version_id).to be_nil
    end

    it 'returns 404 for non-existent page' do
      login_as(user)

      post '/api/pages/99999/unpublish', {},
           { 'CONTENT_TYPE' => 'application/json', 'HTTP_X_REQUESTED_WITH' => 'XMLHttpRequest' }

      expect(last_response.status).to eq(404)
    end
  end

  describe 'content_filter_tag support' do
    let(:tag) { Tag.create!(name: 'Ruby', slug: 'ruby') }

    describe 'GET /api/pages/:id' do
      it 'includes content_filter_tag_id and content_filter_tag in response' do
        page = Page.create!(title: 'Tag Page', slug: 'tag-page', content_filter_tag_id: tag.id)
        page.publish!

        get "/api/pages/#{page.id}"

        expect(last_response).to be_ok
        data = JSON.parse(last_response.body)
        expect(data['page']['content_filter_tag_id']).to eq(tag.id)
        expect(data['page']['content_filter_tag']).to include(
          'id' => tag.id,
          'name' => 'Ruby',
          'slug' => 'ruby'
        )
      end

      it 'returns null content_filter_tag when not set' do
        page = Page.create!(title: 'No Tag Page', slug: 'no-tag-page')
        page.publish!

        get "/api/pages/#{page.id}"

        expect(last_response).to be_ok
        data = JSON.parse(last_response.body)
        expect(data['page']['content_filter_tag_id']).to be_nil
        expect(data['page']['content_filter_tag']).to be_nil
      end
    end

    describe 'POST /api/pages' do
      it 'accepts content_filter_tag_id when creating a page' do
        login_as(user)

        page_data = {
          title: 'Filtered Page',
          content: 'Content',
          content_filter_tag_id: tag.id
        }

        post '/api/pages', page_data.to_json,
             { 'CONTENT_TYPE' => 'application/json', 'HTTP_X_REQUESTED_WITH' => 'XMLHttpRequest' }

        expect(last_response.status).to eq(201)
        data = JSON.parse(last_response.body)
        expect(data['page']['content_filter_tag_id']).to eq(tag.id)
        expect(data['page']['content_filter_tag']['name']).to eq('Ruby')
      end
    end

    describe 'PUT /api/pages/:id' do
      let!(:page) { Page.create!(title: 'Test Page', slug: 'test-page') }

      it 'updates content_filter_tag_id' do
        login_as(user)

        put "/api/pages/#{page.id}",
            { content_filter_tag_id: tag.id }.to_json,
            { 'CONTENT_TYPE' => 'application/json', 'HTTP_X_REQUESTED_WITH' => 'XMLHttpRequest' }

        expect(last_response).to be_ok
        data = JSON.parse(last_response.body)
        expect(data['page']['content_filter_tag_id']).to eq(tag.id)
        expect(data['page']['content_filter_tag']['name']).to eq('Ruby')
      end

      it 'clears content_filter_tag_id when set to null' do
        login_as(user)
        page.update!(content_filter_tag_id: tag.id)

        put "/api/pages/#{page.id}",
            { content_filter_tag_id: nil }.to_json,
            { 'CONTENT_TYPE' => 'application/json', 'HTTP_X_REQUESTED_WITH' => 'XMLHttpRequest' }

        expect(last_response).to be_ok
        data = JSON.parse(last_response.body)
        expect(data['page']['content_filter_tag_id']).to be_nil
        expect(data['page']['content_filter_tag']).to be_nil
      end

      it 'rejects invalid content_filter_tag_id on create' do
        login_as(user)
        post '/api/pages',
             { title: 'Bad Tag', slug: 'bad-tag', content_filter_tag_id: 99999 }.to_json,
             'CONTENT_TYPE' => 'application/json', 'HTTP_X_REQUESTED_WITH' => 'XMLHttpRequest'

        expect(last_response.status).to eq(422)
        data = JSON.parse(last_response.body)
        expect(data['errors']).to include('Content filter tag not found')
      end

      it 'rejects invalid content_filter_tag_id on update' do
        login_as(user)
        page = Page.create!(title: 'Test FK', slug: 'test-fk-page')
        put "/api/pages/#{page.id}",
            { content_filter_tag_id: 99999 }.to_json,
            'CONTENT_TYPE' => 'application/json', 'HTTP_X_REQUESTED_WITH' => 'XMLHttpRequest'

        expect(last_response.status).to eq(422)
        data = JSON.parse(last_response.body)
        expect(data['errors']).to include('Content filter tag not found')
      end

      it 'does not change content_filter_tag_id when not provided' do
        login_as(user)
        page.update!(content_filter_tag_id: tag.id)

        put "/api/pages/#{page.id}",
            { title: 'Updated Title' }.to_json,
            { 'CONTENT_TYPE' => 'application/json', 'HTTP_X_REQUESTED_WITH' => 'XMLHttpRequest' }

        expect(last_response).to be_ok
        data = JSON.parse(last_response.body)
        expect(data['page']['content_filter_tag_id']).to eq(tag.id)
      end
    end
  end
end
