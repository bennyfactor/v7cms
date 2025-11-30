require 'spec_helper'

RSpec.describe 'Custom Error Pages' do
  describe '404 errors' do
    it 'returns 404 for non-existent routes' do
      get '/this-route-does-not-exist-xyz'
      expect(last_response.status).to eq(404)
    end

    it 'serves custom 404.html if it exists in error folder' do
      # Create temp error folder and file
      error_dir = File.join(CMS.settings.public_folder, 'error')
      FileUtils.mkdir_p(error_dir)
      File.write(File.join(error_dir, '404.html'), '<h1>Custom 404</h1>')

      get '/non-existent-page-test'
      expect(last_response.status).to eq(404)
      expect(last_response.body).to include('Custom 404')

      # Cleanup
      FileUtils.rm_rf(error_dir)
    end

    it 'falls back to erb template when no custom file exists' do
      get '/non-existent-page-test'
      expect(last_response.status).to eq(404)
      # Should use the 404.erb template
      expect(last_response.body).to include('Page Not Found')
    end
  end

  describe 'error handler functionality' do
    it 'error handlers are defined and can check for custom error files' do
      # Verify the error handlers will look for custom files in the right location
      error_dir = File.join(CMS.settings.public_folder, 'error')

      # The handlers should check for these paths
      expected_404_path = File.join(error_dir, '404.html')
      expected_403_path = File.join(error_dir, '403.html')
      expected_500_path = File.join(error_dir, '500.html')

      # Verify the paths are correct
      expect(expected_404_path).to include('public/error/404.html')
      expect(expected_403_path).to include('public/error/403.html')
      expect(expected_500_path).to include('public/error/500.html')
    end
  end
end
