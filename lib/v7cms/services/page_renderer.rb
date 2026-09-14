# frozen_string_literal: true

require 'erb'
require 'fileutils'
require 'logger'
require_relative '../helpers/menu_helper'
require_relative 'static_html_helper'

module V7CMS
  class PageRenderer
    include V7CMS::StaticHtmlHelper

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

    def self.delete_static_file_at(slug_path)
      return true if slug_path.to_s.strip.empty?

      dir = File.join(STATIC_DIR, slug_path)
      expanded = File.expand_path(dir)
      static_expanded = File.expand_path(STATIC_DIR)

      unless expanded.start_with?("#{static_expanded}#{File::SEPARATOR}")
        logger.error("Refusing to delete at #{slug_path}: path traversal detected")
        return false
      end

      return true unless Dir.exist?(dir)

      FileUtils.rm_rf(dir)
      cleanup_empty_ancestors(dir)
      logger.info("Deleted static HTML at old path: #{slug_path}")
      true
    rescue => e
      logger.error("Failed to delete static HTML at #{slug_path}: #{e.message}")
      false
    end

    def self.cleanup_empty_ancestors(dir)
      dir_path = File.dirname(dir)
      while dir_path != STATIC_DIR && Dir.exist?(dir_path) && Dir.empty?(dir_path)
        Dir.rmdir(dir_path)
        dir_path = File.dirname(dir_path)
      end
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
      theme = begin
        V7CMS::Theme.instance
      rescue StandardError
        nil
      end
      @header_style = theme_header_style(theme)
      @footer_style = theme_footer_style(theme)
    end

    def render_html
      template = ERB.new(static_template)
      template.result(binding)
    end

    def write_file
      # Layout-template pages (blog_list, portfolio, ...) list other content
      # that changes independently of the page itself, so a pre-baked copy
      # goes stale the moment a post is published. Serve them dynamically:
      # remove any previously generated file so Apache falls through to the app.
      return skip_layout_page if @page.uses_layout_template?

      validate_write_path!
      ensure_directory_exists
      validate_write_path!('after directory creation')
      File.write(static_file_path, render_html)
      self.class.logger.info("Generated static HTML for page: #{@page.slug}")
      true
    rescue => e
      self.class.logger.error("Failed to generate static HTML for page #{@page.slug}: #{e.message}")
      self.class.logger.error(e.backtrace.join("\n"))
      false
    end

    # Remove this page's own index.html and prune directories left empty.
    # Never remove the whole slug directory: it also holds the static files
    # of child pages, which stay published independently of their parent.
    def delete_file
      path = static_file_path
      return true unless File.exist?(path)

      unless safe_path?(path)
        self.class.logger.error("Refusing to delete static HTML for page #{@page.slug}: path traversal detected")
        return false
      end

      File.delete(path)
      prune_empty_directories(File.dirname(path))
      self.class.logger.info("Deleted static HTML for page: #{@page.slug}")
      true
    rescue => e
      self.class.logger.error("Failed to delete static HTML for page #{@page.slug}: #{e.message}")
      self.class.logger.error(e.backtrace.join("\n"))
      false
    end

    private

    def skip_layout_page
      self.class.logger.info("Skipping static HTML for layout page: #{@page.slug} (#{@page.page_type})")
      delete_file
    end

    def prune_empty_directories(dir_path)
      static_root = File.expand_path(STATIC_DIR)
      while File.expand_path(dir_path) != static_root && Dir.exist?(dir_path) && Dir.empty?(dir_path)
        Dir.rmdir(dir_path)
        dir_path = File.dirname(dir_path)
      end
    end

    def validate_write_path!(context = nil)
      return if safe_path?(static_file_path)

      detail = context ? " #{context}" : ''
      raise "Refusing to write static HTML for page #{@page.slug}: path traversal detected#{detail}"
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

    def static_template
      <<~HTML
        <!DOCTYPE html>
        <html lang="en">
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title><%= @title %> - <%= @settings.site_title %></title>
            <%= static_head_assets %>

            <meta name="description" content="<%= @content.to_s.gsub(/<[^>]*>/, '')[0..150] %>">

            <% if @settings.meta_keywords.present? %>
            <meta name="keywords" content="<%= @settings.meta_keywords %>">
            <% end %>

            <% if @settings.site_author.present? %>
            <meta name="author" content="<%= @settings.site_author %>">
            <% end %>

            <%= static_feed_links %>
            <%= custom_partial('_head_custom') %>

            <!-- Static generation timestamp -->
            <!-- Generated: <%= Time.now.utc.iso8601 %> -->
        </head>
        <body class="bg-gray-50 min-h-screen flex flex-col">
            <!-- Header -->
            <header class="<%= header_classes(@header_style) %>">
                <div class="max-w-4xl mx-auto px-4 <%= header_padding(@header_style) %>">
                    <div class="flex justify-between items-center">
                        <div>
                            <a href="/" class="<%= header_title_size(@header_style) %> font-bold text-gray-800 hover:text-blue-600 transition"><%= @settings.site_title %></a>
                            <% if @settings.site_tagline.present? && show_tagline?(@header_style) %>
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
                                            <a href="/<%= parent.full_slug_path %>" class="text-blue-600 hover:text-blue-800 transition">
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
                                            <a href="/<%= child.full_slug_path %>" class="text-blue-600 hover:text-blue-800 font-semibold transition">
                                                <%= child.title %>
                                            </a>
                                        </li>
                                    <% end %>
                                </ul>
                            </section>
                            <% end %>

                            <footer class="mt-12 pt-6 border-t">
                                <% if @page.parent %>
                                    <a href="/<%= @page.parent.full_slug_path %>" class="text-blue-600 hover:text-blue-800 font-semibold transition">
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
            <footer class="<%= footer_classes(@footer_style) %> mt-auto">
                <div class="max-w-4xl mx-auto px-4 <%= footer_padding(@footer_style) %> text-center text-gray-600 <%= footer_text_size(@footer_style) %>">
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

            <%= custom_partial('_body_scripts_custom') %>
        </body>
        </html>
      HTML
    end
  end
end
