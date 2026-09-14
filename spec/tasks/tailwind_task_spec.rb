require 'spec_helper'
require 'rake'
require 'tmpdir'

rake_file = File.expand_path('../../lib/v7cms/tasks/tailwind.rake', __dir__)
load rake_file unless Rake::Task.task_defined?('v7cms:tailwind')

RSpec.describe 'v7cms:tailwind rake task' do # rubocop:disable RSpec/DescribeClass
  let(:project_dir) { Dir.mktmpdir('v7cms_tailwind_project') }
  let(:output_css) { File.join(project_dir, 'public', 'css', 'output.css') }

  before do
    layouts = File.join(project_dir, 'views', 'layouts', 'homepage')
    FileUtils.mkdir_p(layouts)
    File.write(File.join(layouts, '_custom.erb'), '<div class="mt-[321px]"></div>')
    FileUtils.mkdir_p(File.join(project_dir, 'public', 'js'))
    File.write(File.join(project_dir, 'public', 'widget.html'), '<div class="mt-[432px]"></div>')
    File.write(File.join(project_dir, 'public', 'js', 'widget.js'), "el.className = 'mt-[543px]'")
    # A gitignored directory must not matter: sources are explicit
    File.write(File.join(project_dir, '.gitignore'), "vendor/\n")
    FileUtils.mkdir_p(File.join(project_dir, 'vendor'))
    allow(V7CMS).to receive(:project_root).and_return(project_dir)
  end

  after do
    FileUtils.remove_entry(project_dir)
  end

  def run_task
    Dir.chdir(project_dir) do
      Rake::Task['v7cms:tailwind'].reenable
      expect { Rake::Task['v7cms:tailwind'].invoke }.to output(/Done!/).to_stdout
    end
  end

  it 'compiles classes from the gem views and the project views into the project stylesheet' do
    run_task
    css = File.read(output_css)
    expect(css).to include('321px')       # project layout class
    expect(css).to include('432px')       # project public HTML
    expect(css).to include('543px')       # project public JS
    expect(css).to include('.max-w-4xl')  # gem layout.erb class
  end

  it 'removes its temporary build directory' do
    run_task
    expect(Dir.glob(File.join(project_dir, '.tmp', 'tailwind-*'))).to be_empty
  end

  it 'removes its temporary build directory when writing the entry file fails' do
    allow(File).to receive(:write).and_call_original
    allow(File).to receive(:write).with(/entry\.css\z/, anything).and_raise(Errno::EACCES, 'read-only')
    Dir.chdir(project_dir) do
      Rake::Task['v7cms:tailwind'].reenable
      expect { Rake::Task['v7cms:tailwind'].invoke }.to raise_error(Errno::EACCES)
    end
    expect(Dir.glob(File.join(project_dir, '.tmp', 'tailwind-*'))).to be_empty
  end
end
