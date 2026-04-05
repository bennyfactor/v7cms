require 'spec_helper'
require 'rake'
require 'tmpdir'

# Load rake tasks
Rails = nil unless defined?(Rails) # Prevent double-load issues
rake_file = File.expand_path('../../lib/v7cms/tasks/v7cms.rake', __dir__)
load rake_file unless Rake::Task.task_defined?('v7cms:assets')

RSpec.describe 'v7cms:assets rake task' do
  let(:project_dir) { Dir.mktmpdir('v7cms_test_project') }
  let(:project_public) { File.join(project_dir, 'public') }
  let(:gem_public) { File.join(V7CMS.gem_root, 'lib', 'v7cms', 'public') }

  before do
    FileUtils.mkdir_p(project_public)
    allow(V7CMS).to receive(:project_root).and_return(project_dir)
  end

  after do
    FileUtils.remove_entry(project_dir)
  end

  def run_assets_task
    Rake::Task['v7cms:assets'].reenable
    Rake::Task['v7cms:assets'].invoke
  end

  describe 'file-level symlinks for js directory' do
    it 'creates public/js as a real directory, not a symlink' do
      run_assets_task
      js_dir = File.join(project_public, 'js')
      expect(File.directory?(js_dir)).to be true
      expect(File.symlink?(js_dir)).to be false
    end

    it 'symlinks each gem JS file individually' do
      run_assets_task
      js_dir = File.join(project_public, 'js')
      %w[admin.js comments.js forms.js].each do |js_file|
        target = File.join(js_dir, js_file)
        expect(File.symlink?(target)).to be(true), "Expected #{js_file} to be a symlink"
        expect(File.readlink(target)).to eq(File.join(gem_public, 'js', js_file))
      end
    end

    it 'preserves client-owned files in the js directory' do
      js_dir = File.join(project_public, 'js')
      FileUtils.mkdir_p(js_dir)
      client_file = File.join(js_dir, 'my-custom-script.js')
      File.write(client_file, 'console.log("hello")')

      run_assets_task

      expect(File.exist?(client_file)).to be true
      expect(File.read(client_file)).to eq('console.log("hello")')
      expect(File.symlink?(client_file)).to be false
    end

    it 'migrates an old directory symlink to file-level symlinks' do
      js_target = File.join(project_public, 'js')
      File.symlink(File.join(gem_public, 'js'), js_target)

      run_assets_task

      expect(File.symlink?(js_target)).to be false
      expect(File.directory?(js_target)).to be true
      expect(File.symlink?(File.join(js_target, 'admin.js'))).to be true
    end
  end

  describe 'file-level symlinks for css directory' do
    it 'creates public/css as a real directory with file-level symlinks' do
      run_assets_task
      css_dir = File.join(project_public, 'css')
      expect(File.directory?(css_dir)).to be true
      expect(File.symlink?(css_dir)).to be false
      expect(File.symlink?(File.join(css_dir, 'input.css'))).to be true
    end
  end

  describe 'directory symlinks for admin' do
    it 'symlinks admin as a whole directory' do
      run_assets_task
      admin_dir = File.join(project_public, 'admin')
      expect(File.symlink?(admin_dir)).to be true
      expect(File.readlink(admin_dir)).to eq(File.join(gem_public, 'admin'))
    end
  end

  describe 'file symlink for api-docs.html' do
    it 'symlinks api-docs.html as a single file' do
      run_assets_task
      api_docs = File.join(project_public, 'api-docs.html')
      expect(File.symlink?(api_docs)).to be true
      expect(File.readlink(api_docs)).to eq(File.join(gem_public, 'api-docs.html'))
    end
  end

  describe 'idempotency' do
    it 'can be run multiple times without error' do
      2.times { run_assets_task }
      js_dir = File.join(project_public, 'js')
      expect(File.directory?(js_dir)).to be true
      expect(File.symlink?(js_dir)).to be false
    end

    it 'updates symlinks when gem file is missing and re-run' do
      run_assets_task
      js_file = File.join(project_public, 'js', 'admin.js')
      original_target = File.readlink(js_file)

      FileUtils.rm(js_file)
      run_assets_task

      expect(File.symlink?(js_file)).to be true
      expect(File.readlink(js_file)).to eq(original_target)
    end
  end
end
