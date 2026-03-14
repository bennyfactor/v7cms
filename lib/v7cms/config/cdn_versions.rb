# frozen_string_literal: true

module V7CMS
  # Centralized CDN dependency versions.
  # Update versions here, then run: bundle exec rake v7cms:update_cdn
  # That rewrites the URLs in static HTML files (admin/index.html, api-docs.html).
  # ERB views read from this config at runtime via the CdnHelper.
  CDN_VERSIONS = {
    alpine: {
      version: '3.14.9',
      js: 'https://cdn.jsdelivr.net/npm/alpinejs@%{version}/dist/cdn.min.js',
      js_attrs: 'defer'
    },
    quill: {
      version: '1.3.6',
      js: 'https://cdn.quilljs.com/%{version}/quill.js',
      css: 'https://cdn.quilljs.com/%{version}/quill.snow.css'
    },
    font_awesome: {
      version: '6.5.1',
      css: 'https://cdnjs.cloudflare.com/ajax/libs/font-awesome/%{version}/css/all.min.css',
      css_attrs: 'crossorigin="anonymous"'
    },
    swagger_ui: {
      version: '5.18.2',
      css: 'https://unpkg.com/swagger-ui-dist@%{version}/swagger-ui.css',
      js: 'https://unpkg.com/swagger-ui-dist@%{version}/swagger-ui-bundle.js',
      js2: 'https://unpkg.com/swagger-ui-dist@%{version}/swagger-ui-standalone-preset.js'
    },
    tailwind_browser: {
      version: '4.1.0',
      js: 'https://unpkg.com/@tailwindcss/browser@%{version}'
    }
  }.freeze

  # Resolve a CDN URL by substituting the version into the template
  def self.cdn_url(library, asset_key = :js)
    lib = CDN_VERSIONS[library]
    raise ArgumentError, "Unknown CDN library: #{library}" unless lib

    template = lib[asset_key]
    raise ArgumentError, "No #{asset_key} asset for #{library}" unless template

    format(template, version: lib[:version])
  end
end
