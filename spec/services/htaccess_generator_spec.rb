require 'spec_helper'

RSpec.describe HtaccessGenerator do
  let(:template_path) { HtaccessGenerator::TEMPLATE_PATH }
  let(:generator) { HtaccessGenerator.new }
  let(:output_path) { generator.output_path }

  before do
    # Ensure we have a template file for testing
    unless File.exist?(template_path)
      File.write(template_path, "# Test Template\n{{REDIRECTS}}\n# End")
    end
  end

  after do
    # Clean up generated .htaccess file after tests
    File.delete(output_path) if File.exist?(output_path)
  end

  describe '.generate' do
    it 'creates .htaccess file from template' do
      HtaccessGenerator.generate
      expect(File.exist?(output_path)).to be true
    end

    it 'replaces {{REDIRECTS}} placeholder with empty message when no redirects' do
      HtaccessGenerator.generate
      content = File.read(output_path)
      expect(content).to include('# No custom redirects configured')
      expect(content).not_to include('{{REDIRECTS}}')
    end

    it 'replaces {{REDIRECTS}} placeholder with redirect rules when redirects exist' do
      Redirect.create!(short_path: '/test', target_path: '/posts/test-post')
      Redirect.create!(short_path: '/foo', target_path: '/pages/foo-page')

      HtaccessGenerator.generate
      content = File.read(output_path)

      expect(content).to include('RewriteRule ^test$ /posts/test-post [R=301,L]')
      expect(content).to include('RewriteRule ^foo$ /pages/foo-page [R=301,L]')
      expect(content).not_to include('{{REDIRECTS}}')
    end

    it 'returns true on success' do
      expect(HtaccessGenerator.generate).to be true
    end

    it 'returns false on failure' do
      # Force an error by making the template file unreadable
      allow(File).to receive(:read).with(template_path).and_raise(Errno::ENOENT)
      expect(HtaccessGenerator.generate).to be false
    end
  end

  describe 'template content' do
    let(:template) { File.read(template_path) }

    it 'includes rewrite rules for static asset directories' do
      %w[js css patterns].each do |dir|
        expect(template).to include("RewriteRule ^#{dir}/(.*)$ /public/#{dir}/$1 [L]")
      end
    end

    it 'includes rewrite rules for pre-generated HTML directories' do
      %w[posts pages].each do |dir|
        expect(template).to include("RewriteRule ^#{dir}/(.+\\.html)$ /public/#{dir}/$1 [L]")
      end
    end

    it 'sets long cache for static asset file types' do
      expect(template).to match(/FilesMatch.*js\|css\|wasm/)
      expect(template).to include('max-age=2592000')
    end

    it 'sets short cache for HTML files' do
      expect(template).to match(/FilesMatch.*\\\.html/)
      expect(template).to include('max-age=3600')
    end

    it 'disables caching for FCGI responses via rewrite rule env var' do
      expect(template).to include('no-cache, no-store, must-revalidate')
      expect(template).to include('env=REDIRECT_is_fcgi_request')
      expect(template).to include('E=is_fcgi_request:1')
    end

    it 'does not blanket no-cache JS or CSS files' do
      # The old template had a FilesMatch for .html|js|css with no-cache
      # This should no longer exist
      expect(template).not_to match(/FilesMatch.*html\|js\|css.*\n.*no-cache/)
    end

    it 'includes gzip compression rules' do
      expect(template).to include('mod_deflate')
      expect(template).to include('AddOutputFilterByType DEFLATE')
    end
  end

  describe '#escape_path' do
    it 'removes leading slash' do
      expect(generator.send(:escape_path, '/test')).to eq('test')
    end

    it 'escapes special regex characters' do
      expect(generator.send(:escape_path, '/test.html')).to include('\\.')
    end

    it 'escapes question marks' do
      expect(generator.send(:escape_path, '/test?')).to include('\\?')
    end

    it 'escapes asterisks' do
      expect(generator.send(:escape_path, '/test*')).to include('\\*')
    end

    it 'escapes square brackets' do
      expect(generator.send(:escape_path, '/test[0]')).to include('\\[')
      expect(generator.send(:escape_path, '/test[0]')).to include('\\]')
    end
  end

  describe '#build_redirects_block' do
    it 'returns "no redirects" message when no redirects exist' do
      result = generator.send(:build_redirects_block)
      expect(result).to eq('# No custom redirects configured')
    end

    it 'builds redirect rules ordered by short_path' do
      Redirect.create!(short_path: '/zzz', target_path: '/posts/zzz')
      Redirect.create!(short_path: '/aaa', target_path: '/posts/aaa')
      Redirect.create!(short_path: '/mmm', target_path: '/posts/mmm')

      result = generator.send(:build_redirects_block)
      lines = result.split("\n")

      expect(lines.length).to eq(3)
      expect(lines[0]).to include('aaa')
      expect(lines[1]).to include('mmm')
      expect(lines[2]).to include('zzz')
    end

    it 'generates correct RewriteRule format' do
      Redirect.create!(short_path: '/pricing', target_path: '/posts/pricing-page')

      result = generator.send(:build_redirects_block)
      expect(result).to eq('RewriteRule ^pricing$ /posts/pricing-page [R=301,L]')
    end
  end
end
