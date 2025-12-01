# frozen_string_literal: true

require 'spec_helper'
require_relative '../../lib/v7cms/file_resolver'

RSpec.describe V7CMS::FileResolver do
  let(:project_root) { Dir.mktmpdir('project') }
  let(:gem_root) { Dir.mktmpdir('gem') }
  let(:resolver) { described_class.new(project_root: project_root, gem_root: gem_root) }

  after do
    FileUtils.remove_entry(project_root) if File.exist?(project_root)
    FileUtils.remove_entry(gem_root) if File.exist?(gem_root)
  end

  def create_project_file(relative_path, content = 'project content')
    full_path = File.join(project_root, relative_path)
    FileUtils.mkdir_p(File.dirname(full_path))
    File.write(full_path, content)
    full_path
  end

  def create_gem_file(relative_path, content = 'gem content')
    full_path = File.join(gem_root, 'lib', 'v7cms', relative_path)
    FileUtils.mkdir_p(File.dirname(full_path))
    File.write(full_path, content)
    full_path
  end

  describe '#resolve' do
    context 'when file exists only in project' do
      it 'returns the project path' do
        project_path = create_project_file('views/layout.erb')

        result = resolver.resolve('views/layout.erb')

        expect(result).to eq(project_path)
      end
    end

    context 'when file exists only in gem' do
      it 'returns the gem path' do
        gem_path = create_gem_file('views/layout.erb')

        result = resolver.resolve('views/layout.erb')

        expect(result).to eq(gem_path)
      end
    end

    context 'when file exists in both project and gem' do
      it 'returns the project path (user-first)' do
        project_path = create_project_file('views/layout.erb', 'custom')
        create_gem_file('views/layout.erb', 'default')

        result = resolver.resolve('views/layout.erb')

        expect(result).to eq(project_path)
      end
    end

    context 'when file does not exist in either location' do
      it 'returns nil' do
        result = resolver.resolve('views/nonexistent.erb')

        expect(result).to be_nil
      end
    end
  end

  describe '#resolve_all' do
    context 'when file exists only in project' do
      it 'returns array with only project path' do
        project_path = create_project_file('views/layout.erb')

        result = resolver.resolve_all('views/layout.erb')

        expect(result).to eq([project_path])
      end
    end

    context 'when file exists only in gem' do
      it 'returns array with only gem path' do
        gem_path = create_gem_file('views/layout.erb')

        result = resolver.resolve_all('views/layout.erb')

        expect(result).to eq([gem_path])
      end
    end

    context 'when file exists in both locations' do
      it 'returns array with project path first, then gem path' do
        project_path = create_project_file('views/layout.erb')
        gem_path = create_gem_file('views/layout.erb')

        result = resolver.resolve_all('views/layout.erb')

        expect(result).to eq([project_path, gem_path])
      end
    end

    context 'when file does not exist' do
      it 'returns empty array' do
        result = resolver.resolve_all('views/nonexistent.erb')

        expect(result).to eq([])
      end
    end
  end

  describe '#exist?' do
    it 'returns true when file exists in project' do
      create_project_file('views/layout.erb')

      expect(resolver.exist?('views/layout.erb')).to be true
    end

    it 'returns true when file exists in gem' do
      create_gem_file('views/layout.erb')

      expect(resolver.exist?('views/layout.erb')).to be true
    end

    it 'returns false when file does not exist' do
      expect(resolver.exist?('views/nonexistent.erb')).to be false
    end
  end

  describe '#read' do
    it 'reads content from project file when it exists' do
      create_project_file('config/settings.yml', 'project settings')

      result = resolver.read('config/settings.yml')

      expect(result).to eq('project settings')
    end

    it 'reads content from gem file when project file does not exist' do
      create_gem_file('config/settings.yml', 'default settings')

      result = resolver.read('config/settings.yml')

      expect(result).to eq('default settings')
    end

    it 'prefers project content over gem content' do
      create_project_file('config/settings.yml', 'custom')
      create_gem_file('config/settings.yml', 'default')

      result = resolver.read('config/settings.yml')

      expect(result).to eq('custom')
    end

    it 'returns nil when file does not exist' do
      result = resolver.read('config/nonexistent.yml')

      expect(result).to be_nil
    end
  end

  describe 'directory resolution' do
    it 'resolves directories correctly' do
      FileUtils.mkdir_p(File.join(project_root, 'public', 'css'))

      result = resolver.resolve('public/css')

      expect(result).to eq(File.join(project_root, 'public', 'css'))
    end

    it 'falls back to gem directory' do
      FileUtils.mkdir_p(File.join(gem_root, 'lib', 'v7cms', 'public', 'css'))

      result = resolver.resolve('public/css')

      expect(result).to eq(File.join(gem_root, 'lib', 'v7cms', 'public', 'css'))
    end
  end
end
