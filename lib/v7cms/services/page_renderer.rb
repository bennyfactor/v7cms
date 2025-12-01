# frozen_string_literal: true

require 'erb'
require 'fileutils'
require 'logger'

module V7CMS
  class PageRenderer
    STATIC_DIR = File.join(Dir.pwd, 'public', 'pages')

    def self.logger
      @logger ||= Logger.new(STDOUT)
    end

    def self.render_to_static(page)
      new(page).render_html
    end

    def self.write_static_file(page)
      new(page).write_file
    end

    def self.delete_static_file(page)
      new(page).delete_file
    end

    def initialize(page)
      @page = page
      @settings = V7CMS::Setting.instance
    end

    def render_html
      template = ERB.new(static_template)
      template.result(binding)
    end

    def write_file
      begin
        ensure_directory_exists
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
      return true unless File.exist?(static_file_path)

      begin
        File.delete(static_file_path)
        cleanup_empty_directories
        self.class.logger.info("Deleted static HTML for page: #{@page.slug}")
        true
      rescue => e
        self.class.logger.error("Failed to delete static HTML for page #{@page.slug}: #{e.message}")
        self.class.logger.error(e.backtrace.join("\n"))
        false
      end
    end

    private

    def static_file_path
      File.join(STATIC_DIR, "#{@page.full_slug_path}.html")
    end

    def ensure_directory_exists
      # Get the directory path for the specific file
      dir_path = File.dirname(static_file_path)
      FileUtils.mkdir_p(dir_path) unless Dir.exist?(dir_path)
    end

    def cleanup_empty_directories
      # Start with the parent directory of the deleted file
      dir_path = File.dirname(static_file_path)

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
            <title><%= @page.title %> - <%= @settings.site_title %></title>
            <script src="https://cdn.tailwindcss.com"></script>

            <meta name="description" content="<%= @page.content.to_s.gsub(/<[^>]*>/, '')[0..150] %>">

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
                        <nav class="flex space-x-6" id="main-nav">
                            <a href="/" class="text-gray-600 hover:text-gray-900 transition">Home</a>
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
                                <h1 class="text-4xl font-bold text-gray-900 mb-4"><%= @page.title %></h1>
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
                                <%= @page.content %>
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
