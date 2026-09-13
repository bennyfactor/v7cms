require_relative '../spec_helper'

RSpec.describe PageRenderer do
  let(:page) do
    Page.new(
      title: 'Test Page',
      slug: 'test-page',
      content: '<p>This is test content.</p>',
      status: 'published'
    )
  end

  let(:renderer) { PageRenderer.new(page) }
  let(:static_file_path) { File.join(PageRenderer::STATIC_DIR, 'test-page', 'index.html') }

  before do
    # Clean up any leftover files from previous tests
    FileUtils.rm_rf(PageRenderer::STATIC_DIR) if Dir.exist?(PageRenderer::STATIC_DIR)
    # Ensure settings exist
    Setting.instance
    # Save the page without triggering callbacks
    page.save!(validate: false) if page.new_record?
  end

  after do
    # Clean up any generated files
    FileUtils.rm_rf(PageRenderer::STATIC_DIR) if Dir.exist?(PageRenderer::STATIC_DIR)
  end

  describe 'renders from published version' do
    it 'uses published version content for static file' do
      page = Page.create!(title: 'Draft', slug: 'test', content: '<p>Draft</p>', status: 'draft')
      version = page.content_versions.create!(
        version_number: 1, version_type: 'workflow', workflow_state: 'published',
        title: 'Published', content: '<p>Published</p>'
      )
      page.update_column(:published_version_id, version.id)

      PageRenderer.write_static_file(page)

      content = File.read(File.join(PageRenderer::STATIC_DIR, 'test', 'index.html'))
      expect(content).to include('Published')
      expect(content).not_to include('Draft')
    end
  end

  describe 'error handling' do
    describe '#write_file' do
      it 'returns true when file write succeeds' do
        result = renderer.write_file
        expect(result).to be true
      end

      it 'returns false when file write fails' do
        allow(File).to receive(:write).and_raise(Errno::EACCES, 'Permission denied')

        result = renderer.write_file
        expect(result).to be false
      end

      it 'logs error when file write fails' do
        logger = instance_double(Logger)
        allow(PageRenderer).to receive(:logger).and_return(logger)
        allow(logger).to receive(:info)
        expect(logger).to receive(:error).with(/Permission denied/)
        expect(logger).to receive(:error).with(kind_of(String))  # backtrace
        allow(File).to receive(:write).and_raise(Errno::EACCES, 'Permission denied')

        renderer.write_file
      end
    end

    describe '#delete_file' do
      it 'returns true when file deletion succeeds' do
        renderer.write_file

        result = renderer.delete_file
        expect(result).to be true
      end

      it 'returns true when file does not exist' do
        result = renderer.delete_file
        expect(result).to be true
      end

      it 'returns false when directory deletion fails' do
        renderer.write_file
        slug_dir = File.join(PageRenderer::STATIC_DIR, page.full_slug_path)
        logger = instance_double(Logger)
        allow(PageRenderer).to receive(:logger).and_return(logger)
        allow(logger).to receive(:info)
        expect(logger).to receive(:error).with(/Permission denied/)
        expect(logger).to receive(:error).with(kind_of(String))  # backtrace
        allow(FileUtils).to receive(:rm_rf).and_call_original
        allow(FileUtils).to receive(:rm_rf).with(slug_dir).and_raise(Errno::EACCES, 'Permission denied')

        result = renderer.delete_file
        expect(result).to be false
      end

      it 'logs error when directory deletion fails' do
        renderer.write_file
        slug_dir = File.join(PageRenderer::STATIC_DIR, page.full_slug_path)
        logger = instance_double(Logger)
        allow(PageRenderer).to receive(:logger).and_return(logger)
        allow(logger).to receive(:info)
        expect(logger).to receive(:error).with(/Permission denied/)
        expect(logger).to receive(:error).with(kind_of(String))  # backtrace
        allow(FileUtils).to receive(:rm_rf).and_call_original
        allow(FileUtils).to receive(:rm_rf).with(slug_dir).and_raise(Errno::EACCES, 'Permission denied')

        renderer.delete_file
      end

      it 'cleans up empty parent directories when deleting files' do
        parent = Page.create!(title: 'Parent', slug: 'parent', status: 'published')
        child = Page.create!(title: 'Child', slug: 'child', parent: parent, status: 'published')

        renderer = PageRenderer.new(child)
        renderer.write_file

        # Verify directory exists
        parent_dir = File.join(PageRenderer::STATIC_DIR, 'parent')
        expect(Dir.exist?(parent_dir)).to be true

        # Delete the file
        renderer.delete_file

        # Parent directory should be removed since it's now empty
        expect(Dir.exist?(parent_dir)).to be false
      end

      it 'does not remove parent directories that still contain files' do
        parent = Page.create!(title: 'Services', slug: 'services', status: 'published')
        child1 = Page.create!(title: 'Web Dev', slug: 'web-dev', parent: parent, status: 'published')
        child2 = Page.create!(title: 'Consulting', slug: 'consulting', parent: parent, status: 'published')

        renderer1 = PageRenderer.new(child1)
        renderer2 = PageRenderer.new(child2)
        renderer1.write_file
        renderer2.write_file

        # Verify both files exist
        parent_dir = File.join(PageRenderer::STATIC_DIR, 'services')
        expect(Dir.exist?(parent_dir)).to be true
        expect(File.exist?(renderer1.send(:static_file_path))).to be true
        expect(File.exist?(renderer2.send(:static_file_path))).to be true

        # Delete only the first child
        renderer1.delete_file

        # Parent directory should still exist because child2's file remains
        expect(Dir.exist?(parent_dir)).to be true
        expect(File.exist?(renderer2.send(:static_file_path))).to be true
      end
    end

    describe 'class method wrappers' do
      it 'write_static_file returns boolean from instance method' do
        allow_any_instance_of(PageRenderer).to receive(:write_file).and_return(false)
        result = PageRenderer.write_static_file(page)
        expect(result).to be false
      end

      it 'delete_static_file returns boolean from instance method' do
        allow_any_instance_of(PageRenderer).to receive(:delete_file).and_return(false)
        result = PageRenderer.delete_static_file(page)
        expect(result).to be false
      end
    end
  end

  describe 'hierarchical path handling' do
    let(:static_dir) { File.join(Dir.pwd, 'public', 'pages') }

    after do
      # Clean up any generated files
      FileUtils.rm_rf(static_dir) if Dir.exist?(static_dir)
    end

    it 'uses parent directory in file path for nested pages' do
      parent = Page.create!(title: 'Services', slug: 'services', status: 'published')
      child = Page.create!(title: 'Web Dev', slug: 'web-dev', parent: parent, status: 'published')

      renderer = PageRenderer.new(child)
      path = renderer.send(:static_file_path)

      # Should include parent directory
      expect(path).to include('services/web-dev/index.html')
      expect(path).not_to eq(File.join(PageRenderer::STATIC_DIR, 'web-dev', 'index.html'))
    end

    it 'generates correct nested directory structure' do
      grandparent = Page.create!(title: 'GP', slug: 'gp', status: 'published')
      parent = Page.create!(title: 'P', slug: 'p', parent: grandparent, status: 'published')
      child = Page.create!(title: 'C', slug: 'c', parent: parent, status: 'published')

      renderer = PageRenderer.new(child)
      path = renderer.send(:static_file_path)

      # Should be: public/pages/gp/p/c/index.html
      expect(path).to end_with('gp/p/c/index.html')
      expect(path).to include('public/pages/')
    end

    it 'handles top-level pages correctly' do
      page = Page.create!(title: 'About', slug: 'about', status: 'published')

      renderer = PageRenderer.new(page)
      path = renderer.send(:static_file_path)

      # Should be: public/pages/about/index.html (no double pages/)
      expect(path).to end_with('pages/about/index.html')
      expect(path).not_to include('pages/pages')
    end

    it 'creates nested directories when writing files' do
      parent = Page.create!(title: 'Parent', slug: 'parent', status: 'published')
      child = Page.create!(title: 'Child', slug: 'child', parent: parent, status: 'published')

      renderer = PageRenderer.new(child)
      result = renderer.write_file

      expect(result).to be true

      # Verify file exists in nested location
      path = renderer.send(:static_file_path)
      expect(File.exist?(path)).to be true
      expect(path).to include('parent/child/index.html')
    end
  end

  describe 'layout-template pages' do
    let(:static_dir) { File.join(Dir.pwd, 'public', 'pages') }

    after do
      FileUtils.rm_rf(static_dir) if Dir.exist?(static_dir)
    end

    it 'does not write a static file for a page that uses a layout template' do
      page = Page.create!(title: 'Blog', slug: 'blog', page_type: 'blog_list', content_source: 'posts')
      page.publish!

      expect(PageRenderer.write_static_file(page)).to be true
      expect(File.exist?(File.join(static_dir, 'blog', 'index.html'))).to be false
    end

    it 'removes a stale static file when a page uses a layout template' do
      page = Page.create!(title: 'Blog', slug: 'blog', page_type: 'blog_list', content_source: 'posts')
      page.publish!
      stale = File.join(static_dir, 'blog', 'index.html')
      FileUtils.mkdir_p(File.dirname(stale))
      File.write(stale, '<html>stale</html>')

      expect(PageRenderer.write_static_file(page)).to be true
      expect(File.exist?(stale)).to be false
    end

    it 'keeps static files of child pages when removing a layout parent' do
      parent = Page.create!(title: 'Wish List', slug: 'wish-list', page_type: 'portfolio')
      parent.publish!
      child = Page.create!(title: 'Item', slug: 'item', parent: parent, page_type: 'standard')
      child.publish!
      child_file = File.join(static_dir, 'wish-list', 'item', 'index.html')
      expect(File.exist?(child_file)).to be true
      stale_parent = File.join(static_dir, 'wish-list', 'index.html')
      File.write(stale_parent, '<html>stale</html>')

      expect(PageRenderer.write_static_file(parent)).to be true
      expect(File.exist?(stale_parent)).to be false
      expect(File.exist?(child_file)).to be true
    end

    it 'prunes the empty directory left behind by a layout page' do
      page = Page.create!(title: 'Blog', slug: 'blog', page_type: 'blog_list', content_source: 'posts')
      page.publish!
      stale = File.join(static_dir, 'blog', 'index.html')
      FileUtils.mkdir_p(File.dirname(stale))
      File.write(stale, '<html>stale</html>')

      PageRenderer.write_static_file(page)
      expect(Dir.exist?(File.join(static_dir, 'blog'))).to be false
    end

    it 'still writes static files for standard pages' do
      page = Page.create!(title: 'About', slug: 'about', page_type: 'standard')
      page.publish!

      expect(File.exist?(File.join(static_dir, 'about', 'index.html'))).to be true
    end
  end

  describe 'parity with the dynamic layout' do
    it 'links the compiled stylesheet and theme instead of the Tailwind CDN' do
      html = renderer.render_html
      expect(html).to include('<link rel="stylesheet" href="/css/output.css">')
      expect(html).to include('<link rel="stylesheet" href="/css/theme.css">')
      expect(html).not_to include('cdn.tailwindcss.com')
    end

    it 'includes feed discovery links' do
      html = renderer.render_html
      expect(html).to include('href="/feed/rss"')
      expect(html).to include('href="/feed/atom"')
    end

    context 'with client template hook partials' do
      around do |example|
        project_dir = Dir.mktmpdir('v7cms_static_project')
        partials_dir = File.join(project_dir, 'views', 'partials')
        FileUtils.mkdir_p(partials_dir)
        File.write(File.join(partials_dir, '_head_custom.erb'), '<meta name="static-head-hook" content="<%= @settings.site_title %>">')
        File.write(File.join(partials_dir, '_body_scripts_custom.erb'), '<script src="/js/static-body-hook.js"></script>')

        original_root = V7CMS.project_root
        V7CMS.configure { |c| c.project_root = project_dir }
        example.run
      ensure
        V7CMS.configure { |c| c.project_root = original_root }
        FileUtils.remove_entry(project_dir)
      end

      it 'renders the client head and body partials with settings available' do
        html = renderer.render_html
        expect(html).to include(%(<meta name="static-head-hook" content="#{Setting.instance.site_title}">))
        expect(html).to include('<script src="/js/static-body-hook.js"></script>')
      end
    end

    context 'when a partial cannot be rendered outside a request' do
      around do |example|
        project_dir = Dir.mktmpdir('v7cms_static_project')
        partials_dir = File.join(project_dir, 'views', 'partials')
        FileUtils.mkdir_p(partials_dir)
        File.write(File.join(partials_dir, '_head_custom.erb'), '<%= request.path %>')

        original_root = V7CMS.project_root
        V7CMS.configure { |c| c.project_root = project_dir }
        example.run
      ensure
        V7CMS.configure { |c| c.project_root = original_root }
        FileUtils.remove_entry(project_dir)
      end

      it 'skips the partial and still renders the document' do
        expect(described_class.logger).to receive(:warn).with(/Skipping partial _head_custom/)
        html = renderer.render_html
        expect(html).to include('</html>')
      end
    end
  end
end
