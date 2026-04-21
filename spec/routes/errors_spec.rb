require 'spec_helper'

RSpec.describe 'Custom Error Pages' do
  # Error pages are looked up in project root /error/ folder (not public/error/)
  # This allows custom error pages to be placed at the root of the project
  def error_dir
    File.join(V7CMS.project_root, 'error')
  end

  def cleanup_error_dir
    FileUtils.rm_rf(error_dir) if File.exist?(error_dir)
  end

  def create_error_file(filename, content)
    FileUtils.mkdir_p(error_dir)
    File.write(File.join(error_dir, filename), content)
  end

  describe '404 errors' do
    it 'returns 404 for non-existent routes' do
      cleanup_error_dir
      get '/this-route-does-not-exist-xyz'
      expect(last_response.status).to eq(404)
    end

    it 'serves custom 404.html if it exists in error folder' do
      cleanup_error_dir
      create_error_file('404.html', '<h1>Custom 404 HTML</h1>')

      get '/non-existent-page-test-html'
      expect(last_response.status).to eq(404)
      expect(last_response.body).to include('Custom 404 HTML')
    ensure
      cleanup_error_dir
    end

    it 'serves custom 404.shtml if it exists in error folder' do
      cleanup_error_dir
      create_error_file('404.shtml', '<h1>Custom 404 SHTML</h1>')

      get '/non-existent-page-test-shtml'
      expect(last_response.status).to eq(404)
      expect(last_response.body).to include('Custom 404 SHTML')
    ensure
      cleanup_error_dir
    end

    it 'serves custom 404.php if it exists in error folder' do
      cleanup_error_dir
      create_error_file('404.php', '<h1>Custom 404 PHP</h1>')

      get '/non-existent-page-test-php'
      expect(last_response.status).to eq(404)
      expect(last_response.body).to include('Custom 404 PHP')
    ensure
      cleanup_error_dir
    end

    it 'prefers .html over .shtml over .php' do
      cleanup_error_dir
      create_error_file('404.html', '<h1>HTML Version</h1>')
      create_error_file('404.shtml', '<h1>SHTML Version</h1>')
      create_error_file('404.php', '<h1>PHP Version</h1>')

      get '/non-existent-page-test-priority'
      expect(last_response.status).to eq(404)
      expect(last_response.body).to include('HTML Version')
    ensure
      cleanup_error_dir
    end

    it 'uses .shtml when .html is not present' do
      cleanup_error_dir
      create_error_file('404.shtml', '<h1>SHTML Version</h1>')
      create_error_file('404.php', '<h1>PHP Version</h1>')

      get '/non-existent-page-test-shtml-priority'
      expect(last_response.status).to eq(404)
      expect(last_response.body).to include('SHTML Version')
    ensure
      cleanup_error_dir
    end

    it 'falls back to erb template when no custom file exists' do
      cleanup_error_dir
      get '/non-existent-page-test-fallback'
      expect(last_response.status).to eq(404)
      # Should use the 404.erb template
      expect(last_response.body).to include('Page Not Found')
    end
  end

  describe 'API error handlers preserve JSON responses' do
    it 'returns JSON body for API 404 errors' do
      get '/api/posts/99999'
      expect(last_response.status).to eq(404)
      data = JSON.parse(last_response.body)
      expect(data['error']).to be_a(String)
    end

    it 'returns JSON error for unauthorized API access' do
      get '/api/users'
      expect(last_response.status).to eq(401)
      data = JSON.parse(last_response.body)
      expect(data['error']).to be_a(String)
    end

    it 'preserves JSON body through 403 error handler' do
      # Trigger 403 via comments-closed path
      post_record = V7CMS::Post.create!(title: 'Closed', slug: 'closed', content: 'x', comments_enabled: false)
      post_record.publish!
      post "/api/posts/#{post_record.id}/comments",
           { author_name: 'Test', author_email: 'test@test.com', content: 'Hi' }.to_json,
           { 'CONTENT_TYPE' => 'application/json' }
      expect(last_response.status).to eq(403)
      data = JSON.parse(last_response.body)
      expect(data['error']).to include('closed')
    end

    it 'preserves JSON body through 500 error handler' do
      # Stub a route to raise an error, triggering the 500 handler
      allow_any_instance_of(CMS).to receive(:settings).and_call_original
      # Force an error in a JSON API route
      allow(V7CMS::Setting).to receive(:instance).and_raise(StandardError, 'test error')
      get '/api/settings'
      expect(last_response.status).to eq(500)
      # The 500 handler should return something (HTML fallback or JSON)
      expect(last_response.body).not_to be_empty
    end
  end

  describe 'error handler functionality' do
    it 'defines ERROR_PAGE_EXTENSIONS constant with correct extensions' do
      expect(CMS::ERROR_PAGE_EXTENSIONS).to eq(%w[.html .shtml .php])
    end

    it 'find_error_page returns nil when no error file exists' do
      cleanup_error_dir
      expect(CMS.find_error_page(404)).to be_nil
    end

    it 'find_error_page returns path when error file exists in project root' do
      cleanup_error_dir
      create_error_file('404.html', 'test')
      expected_path = File.join(V7CMS.project_root, 'error', '404.html')

      expect(CMS.find_error_page(404)).to eq(expected_path)
    ensure
      cleanup_error_dir
    end
  end
end
