# frozen_string_literal: true

require 'fileutils'

namespace :v7cms do
  desc 'Build Tailwind CSS from input.css to output.css'
  task :tailwind do
    require 'tailwindcss/ruby'

    gem_root = File.expand_path('../../..', __dir__)
    input = File.join(gem_root, 'lib', 'v7cms', 'public', 'css', 'input.css')
    output = File.join(gem_root, 'lib', 'v7cms', 'public', 'css', 'output.css')

    # Content paths: gem views and public assets
    content_paths = [
      File.join(gem_root, 'lib', 'v7cms', 'views', '**', '*.erb'),
      File.join(gem_root, 'lib', 'v7cms', 'public', '**', '*.html'),
      File.join(gem_root, 'lib', 'v7cms', 'public', '**', '*.js')
    ]

    # Add project paths if running from a project context
    if defined?(V7CMS) && V7CMS.respond_to?(:project_root)
      project_root = V7CMS.project_root
      content_paths += [
        File.join(project_root, 'views', '**', '*.erb'),
        File.join(project_root, 'public', '**', '*.html'),
        File.join(project_root, 'public', '**', '*.js')
      ]
    end

    exe = Tailwindcss::Ruby.executable

    cmd = [
      exe,
      '-i', input,
      '-o', output,
      '--content', content_paths.join(','),
      '--minify'
    ]

    puts "Building Tailwind CSS..."
    puts "  Input:   #{input}"
    puts "  Output:  #{output}"
    puts "  Content: #{content_paths.length} paths"

    # Use .tmp in working directory to avoid noexec /tmp on shared hosting
    tmpdir = File.join(Dir.pwd, '.tmp')
    FileUtils.mkdir_p(tmpdir)
    env = { 'TMPDIR' => tmpdir }

    begin
      success = system(env, *cmd)
      if success
        size = File.size(output)
        puts "  Done! #{size} bytes (#{(size / 1024.0).round(1)} KB)"
      else
        abort "Tailwind CSS build failed!"
      end
    ensure
      FileUtils.rm_rf(tmpdir)
    end
  end
end
