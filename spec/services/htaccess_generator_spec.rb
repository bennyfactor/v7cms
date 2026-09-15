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

      expect(content).to include('RewriteRule ^test/?$ /posts/test-post [R=301,L]')
      expect(content).to include('RewriteRule ^foo/?$ /pages/foo-page [R=301,L]')
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
      expect(template).to include('RewriteRule ^posts/([^/.]+)/?$ /public/posts/$1/index.html [L]')
      expect(template).to include('RewriteRule ^pages/([a-z0-9-]+(/[a-z0-9-]+)*)/?$ /public/pages/$1/index.html [L]')
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

    it 'disables mod_expires to prevent conflicting cache headers' do
      expect(template).to include('ExpiresActive Off')
    end

    it 'does not blanket no-cache JS or CSS files' do
      # The old template had a FilesMatch for .html|js|css with no-cache
      # This should no longer exist
      expect(template).not_to match(/FilesMatch.*html\|js\|css.*\n.*no-cache/)
    end

    describe 'well-known public files are not blocked' do
      # Pull every RedirectMatch 404 pattern out of the template and evaluate it
      # the way Apache would (PCRE, matched against the URL path).
      let(:blocked_patterns) do
        template.scan(/^RedirectMatch 404 (\S+)$/).flatten.map { |pat| Regexp.new(pat) }
      end

      def blocked?(path)
        blocked_patterns.any? { |re| re.match?(path) }
      end

      it 'lets robots.txt through while still blocking other text files' do
        expect(blocked?('/robots.txt')).to be false
        expect(blocked?('/notes.txt')).to be true
        expect(blocked?('/docs/robots.txt.bak')).to be true
      end

      it 'lets the root .well-known through while still blocking other dotfiles' do
        expect(blocked?('/.well-known/acme-challenge/abc123')).to be false
        expect(blocked?('/.well-known/security.txt')).to be false
        expect(blocked?('/uploads/.well-known/acme-challenge/x')).to be true
        expect(blocked?('/.env')).to be true
        expect(blocked?('/.git/HEAD')).to be true
      end

      it 'exempts the robots.txt basename from the FilesMatch text-file deny block' do
        # FilesMatch is evaluated against the basename only
        pattern = template[/<FilesMatch "([^"]*txt[^"]*)">\s*<IfModule mod_authz_core\.c>\s*Require all denied/, 1]
        expect(pattern).not_to be_nil
        deny = Regexp.new(pattern)
        expect(deny.match?('robots.txt')).to be false
        expect(deny.match?('notes.txt')).to be true
        expect(deny.match?('README.md')).to be true
      end
    end

    it 'sends HSTS only on HTTPS responses' do
      expect(template).to match(/Header always set Strict-Transport-Security "max-age=\d+" env=HTTPS/)
    end

    it 'sets baseline security headers for static responses' do
      expect(template).to include('Header always set X-Content-Type-Options "nosniff"')
      expect(template).to include('Header always set X-Frame-Options "SAMEORIGIN"')
      expect(template).to include('Header always set Referrer-Policy "strict-origin-when-cross-origin"')
    end

    it 'unsets app-provided security headers in both tables before setting them, to avoid duplicates' do
      %w[X-Content-Type-Options X-Frame-Options].each do |name|
        expect(template).to include("Header always unset #{name}")
        expect(template).to include("Header unset #{name}")
        expect(template.index("Header always unset #{name}")).to be < template.index("Header always set #{name}")
      end
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
      expect(result).to eq('RewriteRule ^pricing/?$ /posts/pricing-page [R=301,L]')
    end

    it 'emits one rule when legacy rows exist for both /foo and /foo/' do
      Redirect.create!(short_path: '/dup', target_path: '/pages/dup')
      legacy = Redirect.create!(short_path: '/dup-tmp', target_path: '/pages/dup')
      legacy.update_column(:short_path, '/dup/')

      result = generator.send(:build_redirects_block)
      expect(result.lines.grep(/\^dup/).length).to eq(1)
    end

    it 'does not double the optional trailing slash when short_path already ends with one' do
      Redirect.create!(short_path: '/legacy/', target_path: '/pages/legacy')

      result = generator.send(:build_redirects_block)
      expect(result).to eq('RewriteRule ^legacy/?$ /pages/legacy [R=301,L]')
    end
  end
end
