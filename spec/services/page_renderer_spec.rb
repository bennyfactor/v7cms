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
  let(:static_file_path) { File.join(PageRenderer::STATIC_DIR, 'test-page.html') }

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

      content = File.read(File.join(PageRenderer::STATIC_DIR, 'test.html'))
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

      it 'returns false when file deletion fails' do
        renderer.write_file
        logger = instance_double(Logger)
        allow(PageRenderer).to receive(:logger).and_return(logger)
        allow(logger).to receive(:info)
        expect(logger).to receive(:error).with(/Permission denied/)
        expect(logger).to receive(:error).with(kind_of(String))  # backtrace
        allow(File).to receive(:delete).and_raise(Errno::EACCES, 'Permission denied')

        result = renderer.delete_file
        expect(result).to be false
      end

      it 'logs error when file deletion fails' do
        renderer.write_file
        logger = instance_double(Logger)
        allow(PageRenderer).to receive(:logger).and_return(logger)
        allow(logger).to receive(:info)
        expect(logger).to receive(:error).with(/Permission denied/)
        expect(logger).to receive(:error).with(kind_of(String))  # backtrace
        allow(File).to receive(:delete).and_raise(Errno::EACCES, 'Permission denied')

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
      expect(path).to include('services/web-dev.html')
      expect(path).not_to eq(File.join(PageRenderer::STATIC_DIR, 'web-dev.html'))
    end

    it 'generates correct nested directory structure' do
      grandparent = Page.create!(title: 'GP', slug: 'gp', status: 'published')
      parent = Page.create!(title: 'P', slug: 'p', parent: grandparent, status: 'published')
      child = Page.create!(title: 'C', slug: 'c', parent: parent, status: 'published')

      renderer = PageRenderer.new(child)
      path = renderer.send(:static_file_path)

      # Should be: public/pages/gp/p/c.html
      expect(path).to end_with('gp/p/c.html')
      expect(path).to include('public/pages/')
    end

    it 'handles top-level pages correctly' do
      page = Page.create!(title: 'About', slug: 'about', status: 'published')

      renderer = PageRenderer.new(page)
      path = renderer.send(:static_file_path)

      # Should be: public/pages/about.html (no double pages/)
      expect(path).to end_with('pages/about.html')
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
      expect(path).to include('parent/child.html')
    end
  end
end
