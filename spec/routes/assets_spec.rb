# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Assets API', type: :request do
  let(:admin_user) { V7CMS::User.create!(email: 'admin@example.com', name: 'Admin', provider: 'google_oauth2', uid: '123', admin: true) }
  let(:asset_attributes) do
    {
      filename: 'photo.jpg',
      original_filename: 'My Photo.jpg',
      content_type: 'image/jpeg',
      file_size: 1024,
      storage_key: '2025/12/photo.jpg',
      width: 800,
      height: 600
    }
  end

  def login_as(user)
    env 'rack.session', { user_id: user.id }
  end

  describe 'GET /api/assets' do
    it 'returns empty array when no assets' do
      get '/api/assets'
      expect(last_response).to be_ok
      expect(JSON.parse(last_response.body)['assets']).to eq([])
    end

    it 'returns paginated assets' do
      3.times do |i|
        V7CMS::Asset.create!(asset_attributes.merge(storage_key: "2025/12/photo-#{i}.jpg", filename: "photo-#{i}.jpg"))
      end

      get '/api/assets', per_page: 2
      body = JSON.parse(last_response.body)

      expect(body['assets'].length).to eq(2)
      expect(body['pagination']['total']).to eq(3)
      expect(body['pagination']['pages']).to eq(2)
    end

    it 'filters by type' do
      V7CMS::Asset.create!(asset_attributes.merge(storage_key: '2025/12/a.jpg'))
      V7CMS::Asset.create!(asset_attributes.merge(storage_key: '2025/12/b.pdf', content_type: 'application/pdf'))

      get '/api/assets', type: 'image'
      body = JSON.parse(last_response.body)

      expect(body['assets'].length).to eq(1)
      expect(body['assets'][0]['content_type']).to eq('image/jpeg')
    end

    it 'searches by filename' do
      V7CMS::Asset.create!(asset_attributes.merge(storage_key: '2025/12/cat.jpg', filename: 'cat.jpg', original_filename: 'cat.jpg'))
      V7CMS::Asset.create!(asset_attributes.merge(storage_key: '2025/12/dog.jpg', filename: 'dog.jpg', original_filename: 'dog.jpg'))

      get '/api/assets', search: 'cat'
      body = JSON.parse(last_response.body)

      expect(body['assets'].length).to eq(1)
      expect(body['assets'][0]['filename']).to eq('cat.jpg')
    end
  end

  describe 'GET /api/assets/:id' do
    it 'returns asset details' do
      asset = V7CMS::Asset.create!(asset_attributes)

      get "/api/assets/#{asset.id}"
      expect(last_response).to be_ok

      body = JSON.parse(last_response.body)
      expect(body['id']).to eq(asset.id)
      expect(body['url']).to eq('/upload/2025/12/photo.jpg')
    end

    it 'returns 404 for non-existent asset' do
      get '/api/assets/99999'
      expect(last_response.status).to eq(404)
    end
  end

  describe 'PUT /api/assets/:id' do
    it 'requires authentication' do
      asset = V7CMS::Asset.create!(asset_attributes)

      put "/api/assets/#{asset.id}", { alt_text: 'Updated' }.to_json, 'CONTENT_TYPE' => 'application/json'
      expect(last_response.status).to eq(401)
    end

    it 'updates alt_text when authenticated' do
      login_as(admin_user)
      asset = V7CMS::Asset.create!(asset_attributes)

      put "/api/assets/#{asset.id}", { alt_text: 'A beautiful photo' }.to_json, 'CONTENT_TYPE' => 'application/json'
      expect(last_response).to be_ok

      asset.reload
      expect(asset.alt_text).to eq('A beautiful photo')
    end
  end

  describe 'DELETE /api/assets/:id' do
    it 'requires authentication' do
      asset = V7CMS::Asset.create!(asset_attributes)

      delete "/api/assets/#{asset.id}"
      expect(last_response.status).to eq(401)
    end

    it 'deletes asset when authenticated' do
      login_as(admin_user)
      asset = V7CMS::Asset.create!(asset_attributes)

      delete "/api/assets/#{asset.id}"
      expect(last_response).to be_ok

      expect(V7CMS::Asset.find_by(id: asset.id)).to be_nil
    end
  end

  describe 'POST /api/assets (multipart upload)' do
    it 'requires authentication' do
      post '/api/assets'
      expect(last_response.status).to eq(401)
    end

    it 'rejects request without file' do
      login_as(admin_user)
      post '/api/assets'
      expect(last_response.status).to eq(400)
      expect(JSON.parse(last_response.body)['error']).to include('No file')
    end

    it 'accepts multipart file upload' do
      login_as(admin_user)
      tempfile = Tempfile.new(['test', '.jpg'])
      tempfile.binmode
      tempfile.write("\xFF\xD8\xFF\xE0") # minimal JPEG header
      tempfile.rewind
      file = Rack::Test::UploadedFile.new(tempfile.path, 'image/jpeg')
      post '/api/assets', file: file
      expect([200, 201]).to include(last_response.status)
    ensure
      tempfile&.close!
    end
  end

  describe 'GET /upload/*' do
    let(:temp_dir) { Dir.mktmpdir('v7cms_test_uploads') }

    before do
      # Set up test upload directory
      allow(V7CMS::Asset).to receive(:storage_adapter).and_return(
        V7CMS::Storage::LocalAdapter.new(base_path: temp_dir)
      )
    end

    after { FileUtils.rm_rf(temp_dir) }

    it 'serves existing file' do
      FileUtils.mkdir_p(File.join(temp_dir, '2025/12'))
      File.write(File.join(temp_dir, '2025/12/test.txt'), 'Hello World')

      get '/upload/2025/12/test.txt'
      expect(last_response).to be_ok
      expect(last_response.body).to eq('Hello World')
    end

    it 'returns 404 for non-existent file' do
      get '/upload/2025/12/nonexistent.txt'
      expect(last_response.status).to eq(404)
    end

    it 'sets correct content type for images' do
      FileUtils.mkdir_p(File.join(temp_dir, '2025/12'))
      # Create a minimal valid JPEG file header
      File.binwrite(File.join(temp_dir, '2025/12/test.jpg'), "\xFF\xD8\xFF\xE0")

      get '/upload/2025/12/test.jpg'
      expect(last_response.content_type).to include('image/jpeg')
    end
  end
end
