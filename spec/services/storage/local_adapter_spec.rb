# frozen_string_literal: true

require 'spec_helper'
require 'tempfile'

RSpec.describe V7CMS::Storage::LocalAdapter do
  let(:temp_dir) { Dir.mktmpdir('v7cms_test_uploads') }
  subject(:adapter) { described_class.new(base_path: temp_dir) }

  after { FileUtils.rm_rf(temp_dir) }

  describe '#store' do
    it 'stores a file at the given key' do
      file = StringIO.new('test content')
      adapter.store(file, '2025/12/test.txt')

      expect(File.exist?(File.join(temp_dir, '2025/12/test.txt'))).to be true
      expect(File.read(File.join(temp_dir, '2025/12/test.txt'))).to eq('test content')
    end

    it 'creates nested directories as needed' do
      file = StringIO.new('nested content')
      adapter.store(file, 'deep/nested/path/file.txt')

      expect(File.exist?(File.join(temp_dir, 'deep/nested/path/file.txt'))).to be true
    end

    it 'handles Tempfile objects' do
      tempfile = Tempfile.new(['test', '.txt'])
      tempfile.write('tempfile content')
      tempfile.rewind

      adapter.store(tempfile, '2025/12/tempfile.txt')

      expect(File.read(File.join(temp_dir, '2025/12/tempfile.txt'))).to eq('tempfile content')
      tempfile.close!
    end
  end

  describe '#retrieve' do
    it 'returns file contents for existing key' do
      FileUtils.mkdir_p(File.join(temp_dir, '2025/12'))
      File.write(File.join(temp_dir, '2025/12/test.txt'), 'stored content')

      data = adapter.retrieve('2025/12/test.txt')
      expect(data).to eq('stored content')
    end

    it 'returns nil for non-existent key' do
      expect(adapter.retrieve('nonexistent.txt')).to be_nil
    end
  end

  describe '#delete' do
    it 'removes the file' do
      path = File.join(temp_dir, '2025/12/delete-me.txt')
      FileUtils.mkdir_p(File.dirname(path))
      File.write(path, 'to be deleted')

      adapter.delete('2025/12/delete-me.txt')

      expect(File.exist?(path)).to be false
    end

    it 'cleans up empty parent directories' do
      path = File.join(temp_dir, '2025/12/only-file.txt')
      FileUtils.mkdir_p(File.dirname(path))
      File.write(path, 'only file')

      adapter.delete('2025/12/only-file.txt')

      expect(Dir.exist?(File.join(temp_dir, '2025/12'))).to be false
      expect(Dir.exist?(File.join(temp_dir, '2025'))).to be false
    end

    it 'does not fail for non-existent key' do
      expect { adapter.delete('nonexistent.txt') }.not_to raise_error
    end
  end

  describe '#url' do
    it 'returns the public URL path' do
      expect(adapter.url('2025/12/image.jpg')).to eq('/upload/2025/12/image.jpg')
    end
  end

  describe '#exists?' do
    it 'returns true for existing file' do
      path = File.join(temp_dir, 'exists.txt')
      File.write(path, 'I exist')

      expect(adapter.exists?('exists.txt')).to be true
    end

    it 'returns false for non-existent file' do
      expect(adapter.exists?('nope.txt')).to be false
    end
  end

  describe '#generate_unique_key' do
    it 'returns YYYY/MM/filename format' do
      key = adapter.generate_unique_key('photo.jpg')
      expect(key).to match(%r{\d{4}/\d{2}/photo\.jpg})
    end

    it 'appends number for conflicts' do
      # Create existing file
      FileUtils.mkdir_p(File.join(temp_dir, Time.now.strftime('%Y/%m')))
      File.write(File.join(temp_dir, Time.now.strftime('%Y/%m/photo.jpg')), 'existing')

      key = adapter.generate_unique_key('photo.jpg')
      expect(key).to match(%r{\d{4}/\d{2}/photo-1\.jpg})
    end

    it 'increments number until unique' do
      date_path = Time.now.strftime('%Y/%m')
      FileUtils.mkdir_p(File.join(temp_dir, date_path))
      File.write(File.join(temp_dir, date_path, 'photo.jpg'), 'existing')
      File.write(File.join(temp_dir, date_path, 'photo-1.jpg'), 'existing')
      File.write(File.join(temp_dir, date_path, 'photo-2.jpg'), 'existing')

      key = adapter.generate_unique_key('photo.jpg')
      expect(key).to match(%r{\d{4}/\d{2}/photo-3\.jpg})
    end
  end
end
