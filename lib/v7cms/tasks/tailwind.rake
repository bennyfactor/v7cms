# frozen_string_literal: true

require 'fileutils'

namespace :v7cms do
  desc 'Build Tailwind CSS from input.css to output.css'
  task :tailwind do
    begin
      require 'tailwindcss/ruby'
    rescue LoadError
      abort <<~MSG
        tailwindcss-ruby gem is required to build CSS.
        Add it to your Gemfile:  gem 'tailwindcss-ruby', '~> 4.2'
        Then run:  bundle install && bundle exec rake v7cms:tailwind
      MSG
    end

    gem_root = File.expand_path('../../..', __dir__)
    input = File.join(gem_root, 'lib', 'v7cms', 'public', 'css', 'input.css')

    # Output to project's public/css/ (or gem's public/css/ when building the gem itself)
    output_dir = if defined?(V7CMS) && V7CMS.respond_to?(:project_root) && V7CMS.project_root != gem_root
                   File.join(V7CMS.project_root, 'public', 'css')
                 else
                   File.join(gem_root, 'lib', 'v7cms', 'public', 'css')
                 end
    FileUtils.mkdir_p(output_dir)
    output = File.join(output_dir, 'output.css')

    # The gem's input.css registers the gem views/public with @source and
    # disables automatic source detection. The Tailwind v4 CLI has no
    # --content flag, so a consuming project's views/ and public/ are added
    # through a generated wrapper entry file that imports input.css.
    project_sources = []
    if defined?(V7CMS) && V7CMS.respond_to?(:project_root) && V7CMS.project_root != gem_root
      project_root = V7CMS.project_root
      project_sources = [
        File.join(project_root, 'views', '**', '*.erb'),
        File.join(project_root, 'public', '**', '*.html'),
        File.join(project_root, 'public', '**', '*.js'),
      ]
    end

    exe = Tailwindcss::Ruby.executable

    puts 'Building Tailwind CSS...'
    puts "  Input:   #{input}"
    puts "  Output:  #{output}"
    puts "  Project sources: #{project_sources.length}"

    # Use unique subdir under .tmp to avoid noexec /tmp on shared hosting
    tmpdir = File.join(Dir.pwd, '.tmp', "tailwind-#{Process.pid}")
    FileUtils.mkdir_p(tmpdir)
    env = { 'TMPDIR' => tmpdir }

    begin
      entry = File.join(tmpdir, 'entry.css')
      File.write(entry, [%(@import "#{input}";), *project_sources.map { |g| %(@source "#{g}";) }, ''].join("\n"))

      cmd = [exe, '-i', entry, '-o', output, '--minify']

      success = system(env, *cmd)
      if success
        size = File.size(output)
        puts "  Done! #{size} bytes (#{(size / 1024.0).round(1)} KB)"
      else
        abort 'Tailwind CSS build failed!'
      end
    ensure
      FileUtils.rm_rf(tmpdir)
    end
  end
end
