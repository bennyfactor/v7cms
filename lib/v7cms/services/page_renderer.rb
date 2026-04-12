# frozen_string_literal: true

require 'erb'
require 'fileutils'
require 'logger'
require_relative '../helpers/menu_helper'

module V7CMS
  class PageRenderer
    STATIC_DIR = File.join(Dir.pwd, 'public', 'pages')

    def self.logger
      @logger ||= Logger.new(STDOUT)
    end

    def self.render_to_static(page)
      new(page).render_html
    end

    def self.write_static_file(page, header_html: nil, footer_html: nil)
      new(page, header_html: header_html, footer_html: footer_html).write_file
    end

    def self.delete_static_file(page)
      new(page).delete_file
    end

    def initialize(page, header_html: nil, footer_html: nil)
      @page = page
      @settings = V7CMS::Setting.instance
      # Use published version for rendering if available
      @version = page.published_version
      @title = @version ? @version.title : page.title
      @content = @version ? @version.content : page.content
      @content = V7CMS::FormHelper.process_form_shortcodes(@content) if defined?(V7CMS::FormHelper)
      @header_menu_html = header_html || V7CMS::MenuHelper.render_menu('header')
      @footer_menu_html = footer_html || V7CMS::MenuHelper.render_menu('footer')
    end

    def render_html
      template = ERB.new(static_template)
      template.result(binding)
    end

    def write_file
      begin
        unless safe_path?(static_file_path)
          self.class.logger.error("Refusing to write static HTML for page #{@page.slug}: path traversal detected")
          return false
        end
        ensure_directory_exists
        unless safe_path?(static_file_path)
          self.class.logger.error("Refusing to write static HTML for page #{@page.slug}: path traversal detected after directory creation")
          return false
        end
        File.write(static_file_path, render_html)
        self.class.logger.info("Generated static HTML for page: #{@page.slug}")
        true
      rescue => e
        self.class.logger.error("Failed to generate static HTML for page #{@page.slug}: #{e.message}")
        self.class.logger.error(e.backtrace.join("\n"))
        false
      end
    end

    def delete_file
      slug_dir = File.join(STATIC_DIR, @page.full_slug_path)
      return true unless Dir.exist?(slug_dir)

      unless safe_path?(slug_dir)
        self.class.logger.error("Refusing to delete static HTML for page #{@page.slug}: path traversal detected")
        return false
      end

      remove_slug_directory(slug_dir)
    end

    private

    def remove_slug_directory(slug_dir)
      FileUtils.rm_rf(slug_dir)
      if Dir.exist?(slug_dir)
        self.class.logger.error("Failed to delete static HTML for page #{@page.slug}: directory still exists at #{slug_dir}")
        return false
      end
      cleanup_empty_directories
      self.class.logger.info("Deleted static HTML for page: #{@page.slug}")
      true
    rescue => e
      self.class.logger.error("Failed to delete static HTML for page #{@page.slug}: #{e.message}")
      self.class.logger.error(e.backtrace.join("\n"))
      false
    end

    def safe_path?(path)
      expanded = File.expand_path(path)
      return false unless expanded.start_with?(File.expand_path(STATIC_DIR) + File::SEPARATOR)

      # Resolve symlinks to catch symlink escapes
      real_static_dir = File.realpath(STATIC_DIR) if Dir.exist?(STATIC_DIR)
      if File.exist?(expanded)
        real_path = File.realpath(expanded)
        return false unless real_static_dir && real_path.start_with?(real_static_dir + File::SEPARATOR)
      end

      # Reject symlink components in the path
      check = expanded
      while check != File.expand_path(STATIC_DIR)
        return false if File.symlink?(check)

        check = File.dirname(check)
      end

      true
    end

    def static_file_path
      File.join(STATIC_DIR, @page.full_slug_path, 'index.html')
    end

    def ensure_directory_exists
      dir_path = File.dirname(static_file_path)
      FileUtils.mkdir_p(dir_path) unless Dir.exist?(dir_path)
    end

    def cleanup_empty_directories
      # Start with the parent of the slug directory (which was already removed)
      slug_dir = File.join(STATIC_DIR, @page.full_slug_path)
      dir_path = File.dirname(slug_dir)

      # Walk up the directory tree, removing empty directories
      while dir_path != STATIC_DIR && Dir.exist?(dir_path)
        # Check if directory is empty
        if Dir.empty?(dir_path)
          Dir.rmdir(dir_path)
          # Move up to parent directory
          dir_path = File.dirname(dir_path)
        else
          # Directory is not empty, stop cleanup
          break
        end
      end
    end

    def static_template
      <<~HTML
        <!DOCTYPE html>
        <html lang="en">
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title><%= @title %> - <%= @settings.site_title %></title>
            <script src="https://cdn.tailwindcss.com"></script>

            <meta name="description" content="<%= @content.to_s.gsub(/<[^>]*>/, '')[0..150] %>">

            <% if @settings.meta_keywords.present? %>
            <meta name="keywords" content="<%= @settings.meta_keywords %>">
            <% end %>

            <% if @settings.site_author.present? %>
            <meta name="author" content="<%= @settings.site_author %>">
            <% end %>

            <!-- Static generation timestamp -->
            <!-- Generated: <%= Time.now.utc.iso8601 %> -->
        </head>
        <body class="bg-gray-50 min-h-screen flex flex-col">
            <!-- Header -->
            <header class="bg-white shadow-sm">
                <div class="max-w-4xl mx-auto px-4 py-6">
                    <div class="flex justify-between items-center">
                        <div>
                            <a href="/" class="text-2xl font-bold text-gray-800 hover:text-blue-600 transition"><%= @settings.site_title %></a>
                            <% if @settings.site_tagline.present? %>
                            <p class="text-sm text-gray-600 mt-1"><%= @settings.site_tagline %></p>
                            <% end %>
                        </div>
                        <nav class="flex space-x-6 items-center" id="main-nav">
                            <%= @header_menu_html %>
                            <!-- Admin link injected via JavaScript -->
                        </nav>
                    </div>
                </div>
            </header>

            <!-- Main Content -->
            <main class="flex-1">
                <div class="max-w-4xl mx-auto px-4 py-8">
                    <article class="bg-white rounded-lg shadow-md overflow-hidden">
                        <div class="p-8">
                            <% if @page.breadcrumb_trail.length > 1 %>
                            <nav class="mb-6">
                                <ol class="flex items-center text-sm text-gray-600">
                                    <% @page.breadcrumb_trail[0..-2].each_with_index do |parent, index| %>
                                        <li class="flex items-center">
                                            <% if index > 0 %>
                                                <span class="mx-2">/</span>
                                            <% end %>
                                            <a href="/pages/<%= parent.slug %>" class="text-blue-600 hover:text-blue-800 transition">
                                                <%= parent.title %>
                                            </a>
                                        </li>
                                    <% end %>
                                </ol>
                            </nav>
                            <% end %>

                            <header class="mb-8 border-b pb-6">
                                <h1 class="text-4xl font-bold text-gray-900 mb-4"><%= @title %></h1>
                                <div class="flex items-center text-gray-600 text-sm">
                                    <time datetime="<%= @page.created_at.iso8601 %>">
                                        Published on <%= @page.created_at.strftime(@settings.date_format) %>
                                    </time>
                                    <% if @page.updated_at != @page.created_at %>
                                        <span class="mx-2">•</span>
                                        <span>Updated <%= @page.updated_at.strftime(@settings.date_format) %></span>
                                    <% end %>
                                </div>
                            </header>

                            <div class="prose prose-lg max-w-none">
                                <%= @content %>
                            </div>

                            <% if @page.has_children? %>
                            <section class="mt-12 pt-6 border-t">
                                <h2 class="text-2xl font-bold text-gray-900 mb-4">Subpages</h2>
                                <ul class="space-y-2">
                                    <% @page.children.published.ordered.each do |child| %>
                                        <li>
                                            <a href="/pages/<%= child.slug %>" class="text-blue-600 hover:text-blue-800 font-semibold transition">
                                                <%= child.title %>
                                            </a>
                                        </li>
                                    <% end %>
                                </ul>
                            </section>
                            <% end %>

                            <footer class="mt-12 pt-6 border-t">
                                <% if @page.parent %>
                                    <a href="/pages/<%= @page.parent.slug %>" class="text-blue-600 hover:text-blue-800 font-semibold transition">
                                        ← Back to <%= @page.parent.title %>
                                    </a>
                                <% else %>
                                    <a href="/" class="text-blue-600 hover:text-blue-800 font-semibold transition">
                                        ← Back to home
                                    </a>
                                <% end %>
                            </footer>
                        </div>
                    </article>
                </div>
            </main>

            <!-- Footer -->
            <footer class="bg-white border-t mt-auto">
                <div class="max-w-4xl mx-auto px-4 py-6 text-center text-gray-600 text-sm">
                    <%= @footer_menu_html %>
                    <p>
                        <% if @settings.show_copyright_year %>
                        &copy; <%= Time.now.year %>
                        <% end %>
                        <%= @settings.footer_text %>
                    </p>
                </div>
            </footer>

            <!-- Auth-based UI injection -->
            <script>
                (async function() {
                    try {
                        const response = await fetch('/api/auth/me');
                        const data = await response.json();

                        if (data.logged_in) {
                            const nav = document.getElementById('main-nav');
                            if (nav) {
                                const adminLink = document.createElement('a');
                                adminLink.href = '/admin/';
                                adminLink.className = 'text-gray-600 hover:text-gray-900 transition';
                                adminLink.textContent = 'Admin';
                                nav.appendChild(adminLink);
                            }
                        }
                    } catch (error) {
                        console.error('Failed to check auth status:', error);
                    }
                })();
            </script>
        </body>
        </html>
      HTML
    end
  end
end
