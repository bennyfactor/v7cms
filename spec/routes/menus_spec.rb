# frozen_string_literal: true

require_relative '../spec_helper'

RSpec.describe 'Menus API', type: :request do
  let(:user) { V7CMS::User.create!(email: 'test@example.com', name: 'Test', provider: 'google_oauth2', uid: '12345', admin: true) }

  def app
    CMS
  end

  def login_as(user)
    env 'rack.session', { user_id: user.id }
  end

  describe 'GET /api/menus' do
    it 'requires authentication' do
      get '/api/menus'
      expect(last_response.status).to eq(401)
    end

    it 'returns all menus with item counts' do
      login_as(user)
      menu = V7CMS::Menu.create!(name: 'Main', location: 'header')
      menu.menu_items.create!(label: 'Home', link_type: 'custom', url: '/')
      menu.menu_items.create!(label: 'About', link_type: 'custom', url: '/about')

      get '/api/menus'
      expect(last_response).to be_ok

      data = JSON.parse(last_response.body)
      expect(data['menus'].length).to eq(1)
      expect(data['menus'].first['name']).to eq('Main')
      expect(data['menus'].first['item_count']).to eq(2)
    end
  end

  describe 'GET /api/menus/:id' do
    it 'requires authentication' do
      menu = V7CMS::Menu.create!(name: 'Test')
      get "/api/menus/#{menu.id}"
      expect(last_response.status).to eq(401)
    end

    it 'returns menu with nested items' do
      login_as(user)
      menu = V7CMS::Menu.create!(name: 'Main')
      parent = menu.menu_items.create!(label: 'Blog', link_type: 'custom', url: '/blog')
      menu.menu_items.create!(label: 'Archives', link_type: 'custom', url: '/archives', parent: parent)

      get "/api/menus/#{menu.id}"
      expect(last_response).to be_ok

      data = JSON.parse(last_response.body)
      expect(data['menu']['name']).to eq('Main')
      expect(data['menu']['items'].length).to eq(1)
      expect(data['menu']['items'].first['label']).to eq('Blog')
      expect(data['menu']['items'].first['children'].length).to eq(1)
    end

    it 'finds menu by slug' do
      login_as(user)
      menu = V7CMS::Menu.create!(name: 'Footer Links')

      get "/api/menus/#{menu.slug}"
      expect(last_response).to be_ok

      data = JSON.parse(last_response.body)
      expect(data['menu']['name']).to eq('Footer Links')
    end

    it 'returns 404 for missing menu' do
      login_as(user)
      get '/api/menus/999'
      expect(last_response.status).to eq(404)
    end
  end

  describe 'POST /api/menus' do
    it 'requires authentication' do
      post '/api/menus', { name: 'Test' }.to_json, { 'CONTENT_TYPE' => 'application/json' }
      expect(last_response.status).to eq(401)
    end

    it 'creates a new menu' do
      login_as(user)
      post '/api/menus', { name: 'Footer', location: 'footer' }.to_json,
           { 'CONTENT_TYPE' => 'application/json', 'HTTP_X_REQUESTED_WITH' => 'XMLHttpRequest' }

      expect(last_response.status).to eq(201)
      data = JSON.parse(last_response.body)
      expect(data['menu']['name']).to eq('Footer')
      expect(data['menu']['slug']).to eq('footer')
      expect(data['menu']['location']).to eq('footer')
    end

    it 'returns 422 for invalid menu' do
      login_as(user)
      post '/api/menus', { name: '' }.to_json,
           { 'CONTENT_TYPE' => 'application/json', 'HTTP_X_REQUESTED_WITH' => 'XMLHttpRequest' }

      expect(last_response.status).to eq(422)
    end
  end

  describe 'PUT /api/menus/:id' do
    it 'updates menu properties' do
      login_as(user)
      menu = V7CMS::Menu.create!(name: 'Old Name')

      put "/api/menus/#{menu.id}", { name: 'New Name', location: 'footer' }.to_json,
          { 'CONTENT_TYPE' => 'application/json', 'HTTP_X_REQUESTED_WITH' => 'XMLHttpRequest' }

      expect(last_response).to be_ok
      data = JSON.parse(last_response.body)
      expect(data['menu']['name']).to eq('New Name')
      expect(data['menu']['location']).to eq('footer')
    end
  end

  describe 'DELETE /api/menus/:id' do
    it 'deletes a menu and its items' do
      login_as(user)
      menu = V7CMS::Menu.create!(name: 'Test')
      menu.menu_items.create!(label: 'Home', link_type: 'custom', url: '/')

      expect do
        delete "/api/menus/#{menu.id}", nil,
               { 'HTTP_X_REQUESTED_WITH' => 'XMLHttpRequest' }
      end.to change(V7CMS::Menu, :count).by(-1)
                                        .and change(V7CMS::MenuItem, :count).by(-1)

      expect(last_response).to be_ok
    end
  end

  describe 'POST /api/menus/:id/items' do
    it 'adds a custom link item' do
      login_as(user)
      menu = V7CMS::Menu.create!(name: 'Main')

      post "/api/menus/#{menu.id}/items",
           { label: 'Home', link_type: 'custom', url: '/' }.to_json,
           { 'CONTENT_TYPE' => 'application/json', 'HTTP_X_REQUESTED_WITH' => 'XMLHttpRequest' }

      expect(last_response.status).to eq(201)
      data = JSON.parse(last_response.body)
      expect(data['item']['label']).to eq('Home')
      expect(data['item']['href']).to eq('/')
    end

    it 'adds a page link item' do
      login_as(user)
      menu = V7CMS::Menu.create!(name: 'Main')
      page = V7CMS::Page.create!(title: 'About')

      post "/api/menus/#{menu.id}/items",
           { label: 'About', link_type: 'page', linkable_type: 'V7CMS::Page', linkable_id: page.id }.to_json,
           { 'CONTENT_TYPE' => 'application/json', 'HTTP_X_REQUESTED_WITH' => 'XMLHttpRequest' }

      expect(last_response.status).to eq(201)
      data = JSON.parse(last_response.body)
      expect(data['item']['link_type']).to eq('page')
      expect(data['item']['href']).to eq('/about')
    end

    it 'adds a child item' do
      login_as(user)
      menu = V7CMS::Menu.create!(name: 'Main')
      parent = menu.menu_items.create!(label: 'Blog', link_type: 'custom', url: '/blog')

      post "/api/menus/#{menu.id}/items",
           { label: 'Archives', link_type: 'custom', url: '/archives', parent_id: parent.id }.to_json,
           { 'CONTENT_TYPE' => 'application/json', 'HTTP_X_REQUESTED_WITH' => 'XMLHttpRequest' }

      expect(last_response.status).to eq(201)
      data = JSON.parse(last_response.body)
      expect(data['item']['parent_id']).to eq(parent.id)
    end

    it 'returns 422 for invalid item' do
      login_as(user)
      menu = V7CMS::Menu.create!(name: 'Main')

      post "/api/menus/#{menu.id}/items",
           { label: '', link_type: 'custom' }.to_json,
           { 'CONTENT_TYPE' => 'application/json', 'HTTP_X_REQUESTED_WITH' => 'XMLHttpRequest' }

      expect(last_response.status).to eq(422)
    end
  end

  describe 'PUT /api/menu-items/:id' do
    it 'updates a menu item' do
      login_as(user)
      menu = V7CMS::Menu.create!(name: 'Main')
      item = menu.menu_items.create!(label: 'Old', link_type: 'custom', url: '/')

      put "/api/menu-items/#{item.id}",
          { label: 'New Label', url: '/new' }.to_json,
          { 'CONTENT_TYPE' => 'application/json', 'HTTP_X_REQUESTED_WITH' => 'XMLHttpRequest' }

      expect(last_response).to be_ok
      data = JSON.parse(last_response.body)
      expect(data['item']['label']).to eq('New Label')
    end
  end

  describe 'DELETE /api/menu-items/:id' do
    it 'deletes a menu item' do
      login_as(user)
      menu = V7CMS::Menu.create!(name: 'Main')
      item = menu.menu_items.create!(label: 'Test', link_type: 'custom', url: '/')

      expect do
        delete "/api/menu-items/#{item.id}", nil,
               { 'HTTP_X_REQUESTED_WITH' => 'XMLHttpRequest' }
      end.to change(V7CMS::MenuItem, :count).by(-1)

      expect(last_response).to be_ok
    end
  end

  describe 'GET /api/menus/:slug/render' do
    it 'returns rendered menu HTML without authentication' do
      menu = V7CMS::Menu.create!(name: 'Main', location: 'header')
      menu.menu_items.create!(label: 'Home', link_type: 'custom', url: '/')

      get '/api/menus/header/render'
      expect(last_response).to be_ok

      data = JSON.parse(last_response.body)
      expect(data['html']).to include('Home')
      expect(data['html']).to include('href="/"')
    end

    it 'returns 404 for missing menu' do
      get '/api/menus/nonexistent/render'
      expect(last_response.status).to eq(404)
    end
  end

  describe 'PUT /api/menus/:id/reorder' do
    it 'reorders menu items' do
      login_as(user)
      menu = V7CMS::Menu.create!(name: 'Main')
      item1 = menu.menu_items.create!(label: 'First', link_type: 'custom', url: '/1', position: 0)
      item2 = menu.menu_items.create!(label: 'Second', link_type: 'custom', url: '/2', position: 1)

      put "/api/menus/#{menu.id}/reorder",
          { items: [
            { id: item1.id, position: 1, parent_id: nil },
            { id: item2.id, position: 0, parent_id: nil },
          ] }.to_json,
          { 'CONTENT_TYPE' => 'application/json', 'HTTP_X_REQUESTED_WITH' => 'XMLHttpRequest' }

      expect(last_response).to be_ok
      expect(item1.reload.position).to eq(1)
      expect(item2.reload.position).to eq(0)
    end

    it 'allows reparenting items via reorder' do
      login_as(user)
      menu = V7CMS::Menu.create!(name: 'Main')
      item1 = menu.menu_items.create!(label: 'Parent', link_type: 'custom', url: '/1', position: 0)
      item2 = menu.menu_items.create!(label: 'Child', link_type: 'custom', url: '/2', position: 1)

      put "/api/menus/#{menu.id}/reorder",
          { items: [
            { id: item1.id, position: 0, parent_id: nil },
            { id: item2.id, position: 0, parent_id: item1.id },
          ] }.to_json,
          { 'CONTENT_TYPE' => 'application/json', 'HTTP_X_REQUESTED_WITH' => 'XMLHttpRequest' }

      expect(last_response).to be_ok
      expect(item2.reload.parent_id).to eq(item1.id)
    end
  end
end
