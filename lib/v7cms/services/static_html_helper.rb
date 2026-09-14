# frozen_string_literal: true

require 'erb'
require 'logger'
require_relative '../helpers/theme_style_helper'

module V7CMS
  # Shared pieces for the pre-baked post/page HTML so static files match the
  # dynamic layout.erb: the compiled Tailwind build plus theme.css (instead of
  # the Tailwind browser JIT CDN), the theme's header/footer style classes,
  # and the client's template hook partials.
  module StaticHtmlHelper
    include V7CMS::ThemeStyleHelper

    HEAD_ASSETS = <<~HTML
      <!-- Compiled Tailwind CSS utilities -->
      <link rel="stylesheet" href="/css/output.css">
      <!-- Theme CSS custom properties (regenerated when theme changes) -->
      <link rel="stylesheet" href="/css/theme.css">
      <style>
        /* Apply theme variables to elements */
        body {
          font-family: var(--font-body) !important;
          font-size: var(--font-size-base) !important;
          line-height: var(--line-height-base) !important;
          color: var(--color-text) !important;
          background: var(--color-background) !important;
        }

        h1, h2, h3, h4, h5, h6 {
          font-family: var(--font-heading) !important;
          color: var(--color-heading) !important;
        }

        a {
          color: var(--color-link) !important;
        }

        a:hover {
          color: var(--color-link-hover) !important;
        }

        .container {
          max-width: var(--container-max);
        }

        .border, hr {
          border-color: var(--color-border) !important;
        }

        header.bg-white, footer.bg-white, article.bg-white {
          background-color: var(--color-background) !important;
        }
      </style>
    HTML

    def static_head_assets
      HEAD_ASSETS
    end

    def static_feed_links
      <<~HTML
        <link rel="alternate" type="application/rss+xml" title="#{@settings.site_title} RSS Feed" href="/feed/rss">
        <link rel="alternate" type="application/atom+xml" title="#{@settings.site_title} Atom Feed" href="/feed/atom">
      HTML
    end

    # Render a template hook partial (views/partials/_head_custom.erb or
    # _body_scripts_custom.erb) with this renderer's binding, so the client's
    # project override wins over the gem default. Partials that depend on
    # Sinatra request helpers cannot run here; log and skip rather than fail
    # the whole static build.
    def custom_partial(name)
      path = V7CMS.file_resolver.resolve("views/partials/#{name}.erb")
      return '' unless path

      ERB.new(File.read(path)).result(binding)
    rescue StandardError => e
      self.class.logger.warn("Skipping partial #{name} in static HTML: #{e.class}: #{e.message}")
      ''
    end
  end
end
