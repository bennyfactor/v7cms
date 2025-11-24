require_relative '../spec_helper'
require_relative '../../app/services/page_renderer'

RSpec.describe PageRenderer do
  let(:page) do
    Page.new(
      title: 'Test Page',
      slug: 'test-page',
      content: '<p>This is test content.</p>',
      published: true
    )
  end

  let(:renderer) { PageRenderer.new(page) }
  let(:static_file_path) { File.join(PageRenderer::STATIC_DIR, 'test-page.html') }

  before do
    # Ensure settings exist
    Setting.instance
    # Save the page without triggering callbacks
    page.save!(validate: false) if page.new_record?
  end

  after do
    # Clean up any generated files
    FileUtils.rm_rf(PageRenderer::STATIC_DIR) if Dir.exist?(PageRenderer::STATIC_DIR)
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
end
