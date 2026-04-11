# frozen_string_literal: true

require 'erb'
require 'fileutils'
require 'logger'
require_relative '../helpers/menu_helper'

module V7CMS
  class PostRenderer
    STATIC_DIR = File.join(Dir.pwd, 'public', 'posts')

    def self.logger
      @logger ||= Logger.new(STDOUT)
    end

    def self.render_to_static(post)
      new(post).render_html
    end

    def self.write_static_file(post, header_html: nil, footer_html: nil)
      new(post, header_html: header_html, footer_html: footer_html).write_file
    end

    def self.delete_static_file(post)
      new(post).delete_file
    end

    def initialize(post, header_html: nil, footer_html: nil)
      @post = post
      @settings = V7CMS::Setting.instance
      # Use published version for rendering if available
      @version = post.published_version
      @title = @version ? @version.title : post.title
      @content = @version ? @version.content : post.content
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
        ensure_directory_exists
        File.write(static_file_path, render_html)
        self.class.logger.info("Generated static HTML for post: #{@post.slug}")
        true
      rescue => e
        self.class.logger.error("Failed to generate static HTML for post #{@post.slug}: #{e.message}")
        self.class.logger.error(e.backtrace.join("\n"))
        false
      end
    end

    def delete_file
      slug_dir = File.join(STATIC_DIR, @post.slug)
      return true unless Dir.exist?(slug_dir)

      begin
        FileUtils.rm_rf(slug_dir)
        self.class.logger.info("Deleted static HTML for post: #{@post.slug}")
        true
      rescue => e
        self.class.logger.error("Failed to delete static HTML for post #{@post.slug}: #{e.message}")
        self.class.logger.error(e.backtrace.join("\n"))
        false
      end
    end

    private

    def static_file_path
      File.join(STATIC_DIR, @post.slug, 'index.html')
    end

    def ensure_directory_exists
      dir_path = File.join(STATIC_DIR, @post.slug)
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
            <script src="https://cdn.tailwindcss.com"></script>

            <meta name="description" content="<%= @settings.meta_description %>">

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
                            <header class="mb-8 border-b pb-6">
                                <h1 class="text-4xl font-bold text-gray-900 mb-4"><%= @title %></h1>
                                <div class="flex items-center text-gray-600 text-sm">
                                    <time datetime="<%= @post.created_at.iso8601 %>">
                                        Published on <%= @post.created_at.strftime(@settings.date_format) %>
                                    </time>
                                    <% if @post.updated_at != @post.created_at %>
                                        <span class="mx-2">•</span>
                                        <span>Updated <%= @post.updated_at.strftime(@settings.date_format) %></span>
                                    <% end %>
                                </div>
                            </header>

                            <div class="prose prose-lg max-w-none">
                                <%= @content %>
                            </div>

                            <footer class="mt-12 pt-6 border-t">
                                <a href="/" class="text-blue-600 hover:text-blue-800 font-semibold transition">
                                    ← Back to all posts
                                </a>
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
