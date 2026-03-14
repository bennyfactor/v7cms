# frozen_string_literal: true

module V7CMS
  module CdnHelper
    # Generate a <script> tag for a CDN library
    # Usage in ERB: <%= cdn_script(:alpine) %>
    def cdn_script(library, asset_key = :js)
      lib = V7CMS::CDN_VERSIONS[library]
      raise ArgumentError, "Unknown CDN library: #{library}" unless lib

      url = V7CMS.cdn_url(library, asset_key)
      attrs = lib[:"#{asset_key}_attrs"]
      "<script#{attrs ? " #{attrs}" : ''} src=\"#{url}\"></script>"
    end

    # Generate a <link> tag for a CDN library's CSS
    # Usage in ERB: <%= cdn_css(:quill) %>
    def cdn_css(library, asset_key = :css)
      lib = V7CMS::CDN_VERSIONS[library]
      raise ArgumentError, "Unknown CDN library: #{library}" unless lib

      url = V7CMS.cdn_url(library, asset_key)
      attrs = lib[:"#{asset_key}_attrs"]
      "<link rel=\"stylesheet\" href=\"#{url}\"#{attrs ? " #{attrs}" : ''}>"
    end
  end
end
