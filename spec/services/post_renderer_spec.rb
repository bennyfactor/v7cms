require_relative '../spec_helper'
require_relative '../../app/services/post_renderer'

RSpec.describe PostRenderer do
  let(:post) do
    Post.new(
      title: 'Test Post',
      slug: 'test-post',
      content: '<p>This is test content.</p>',
      published: false # Create as draft to avoid triggering callbacks
    )
  end

  let(:renderer) { PostRenderer.new(post) }
  let(:static_file_path) { File.join(PostRenderer::STATIC_DIR, 'test-post.html') }

  before do
    # Ensure settings exist
    Setting.instance
    # Save the post without triggering callbacks
    post.save!(validate: false) if post.new_record?
  end

  after do
    # Clean up any generated files
    FileUtils.rm_rf(PostRenderer::STATIC_DIR) if Dir.exist?(PostRenderer::STATIC_DIR)
  end

  describe '#render_html' do
    it 'generates complete HTML document' do
      html = renderer.render_html
      expect(html).to include('<!DOCTYPE html>')
      expect(html).to include('<html lang="en">')
      expect(html).to include('</html>')
    end

    it 'includes post title in page title' do
      html = renderer.render_html
      expect(html).to include("<title>#{post.title}")
    end

    it 'includes site title in page title' do
      html = renderer.render_html
      settings = Setting.instance
      expect(html).to include(settings.site_title)
    end

    it 'includes post content' do
      html = renderer.render_html
      expect(html).to include(post.content)
    end

    it 'includes post heading' do
      html = renderer.render_html
      expect(html).to include("<h1 class=\"text-4xl font-bold text-gray-900 mb-4\">#{post.title}</h1>")
    end

    it 'includes formatted publication date' do
      html = renderer.render_html
      settings = Setting.instance
      expected_date = post.created_at.strftime(settings.date_format)
      expect(html).to include(expected_date)
    end

    it 'includes generation timestamp comment' do
      html = renderer.render_html
      expect(html).to include('<!-- Generated:')
    end

    it 'includes meta description' do
      html = renderer.render_html
      settings = Setting.instance
      expect(html).to include(settings.meta_description)
    end

    it 'includes site author in meta tags when present' do
      settings = Setting.instance
      settings.update(site_author: 'Test Author')

      html = renderer.render_html
      expect(html).to include('<meta name="author" content="Test Author">')
    end

    it 'includes navigation link back to home' do
      html = renderer.render_html
      expect(html).to include('← Back to all posts')
      expect(html).to include('href="/"')
    end

    it 'includes site tagline when present' do
      settings = Setting.instance
      settings.update(site_tagline: 'Test Tagline')

      html = renderer.render_html
      expect(html).to include('Test Tagline')
    end

    it 'includes footer text' do
      html = renderer.render_html
      settings = Setting.instance
      expect(html).to include(settings.footer_text)
    end

    it 'includes copyright year when enabled' do
      settings = Setting.instance
      settings.update(show_copyright_year: true)

      html = renderer.render_html
      expect(html).to include("&copy; #{Time.now.year}")
    end
  end

  describe '#write_file' do
    it 'creates static HTML file' do
      expect(File.exist?(static_file_path)).to be false

      renderer.write_file

      expect(File.exist?(static_file_path)).to be true
    end

    it 'creates directory if it does not exist' do
      FileUtils.rm_rf(PostRenderer::STATIC_DIR) if Dir.exist?(PostRenderer::STATIC_DIR)
      expect(Dir.exist?(PostRenderer::STATIC_DIR)).to be false

      renderer.write_file

      expect(Dir.exist?(PostRenderer::STATIC_DIR)).to be true
      expect(File.exist?(static_file_path)).to be true
    end

    it 'writes valid HTML content' do
      renderer.write_file

      content = File.read(static_file_path)
      expect(content).to include('<!DOCTYPE html>')
      expect(content).to include(post.title)
      expect(content).to include(post.content)
    end

    it 'overwrites existing file' do
      renderer.write_file
      original_content = File.read(static_file_path)

      post.update(content: '<p>Updated content</p>')
      renderer.write_file

      new_content = File.read(static_file_path)
      expect(new_content).not_to eq(original_content)
      expect(new_content).to include('Updated content')
    end
  end

  describe '#delete_file' do
    it 'removes static file if it exists' do
      renderer.write_file
      expect(File.exist?(static_file_path)).to be true

      renderer.delete_file

      expect(File.exist?(static_file_path)).to be false
    end

    it 'does not raise error if file does not exist' do
      expect(File.exist?(static_file_path)).to be false

      expect { renderer.delete_file }.not_to raise_error
    end
  end

  describe '.render_to_static' do
    it 'returns HTML string' do
      html = PostRenderer.render_to_static(post)
      expect(html).to be_a(String)
      expect(html).to include('<!DOCTYPE html>')
    end
  end

  describe '.write_static_file' do
    it 'creates static file' do
      expect(File.exist?(static_file_path)).to be false

      PostRenderer.write_static_file(post)

      expect(File.exist?(static_file_path)).to be true
    end
  end

  describe '.delete_static_file' do
    it 'removes static file' do
      PostRenderer.write_static_file(post)
      expect(File.exist?(static_file_path)).to be true

      PostRenderer.delete_static_file(post)

      expect(File.exist?(static_file_path)).to be false
    end
  end

  describe 'error handling' do
    let(:post) { Post.create!(title: 'Test', slug: 'test', content: 'Content', published: true) }

    describe '#write_file' do
      it 'returns true when file write succeeds' do
        renderer = PostRenderer.new(post)
        result = renderer.write_file
        expect(result).to be true
      end

      it 'returns false when file write fails' do
        renderer = PostRenderer.new(post)
        allow(File).to receive(:write).and_raise(Errno::EACCES, 'Permission denied')

        result = renderer.write_file
        expect(result).to be false
      end

      it 'logs error when file write fails' do
        renderer = PostRenderer.new(post)
        logger = instance_double(Logger)
        allow(PostRenderer).to receive(:logger).and_return(logger)
        allow(logger).to receive(:info)
        expect(logger).to receive(:error).with(/Permission denied/)
        expect(logger).to receive(:error).with(kind_of(String))  # backtrace
        allow(File).to receive(:write).and_raise(Errno::EACCES, 'Permission denied')

        renderer.write_file
      end
    end

    describe '#delete_file' do
      it 'returns true when file deletion succeeds' do
        renderer = PostRenderer.new(post)
        renderer.write_file

        result = renderer.delete_file
        expect(result).to be true
      end

      it 'returns true when file does not exist' do
        renderer = PostRenderer.new(post)
        result = renderer.delete_file
        expect(result).to be true
      end

      it 'returns false when file deletion fails' do
        renderer = PostRenderer.new(post)
        renderer.write_file
        allow(File).to receive(:delete).and_raise(Errno::EACCES, 'Permission denied')

        result = renderer.delete_file
        expect(result).to be false
      end

      it 'logs error when file deletion fails' do
        renderer = PostRenderer.new(post)
        renderer.write_file
        logger = instance_double(Logger)
        allow(PostRenderer).to receive(:logger).and_return(logger)
        allow(logger).to receive(:info)
        expect(logger).to receive(:error).with(/Permission denied/)
        expect(logger).to receive(:error).with(kind_of(String))  # backtrace
        allow(File).to receive(:delete).and_raise(Errno::EACCES, 'Permission denied')

        renderer.delete_file
      end
    end

    describe 'class method wrappers' do
      it 'write_static_file returns boolean from instance method' do
        allow_any_instance_of(PostRenderer).to receive(:write_file).and_return(false)
        result = PostRenderer.write_static_file(post)
        expect(result).to be false
      end

      it 'delete_static_file returns boolean from instance method' do
        allow_any_instance_of(PostRenderer).to receive(:delete_file).and_return(false)
        result = PostRenderer.delete_static_file(post)
        expect(result).to be false
      end
    end
  end
end
