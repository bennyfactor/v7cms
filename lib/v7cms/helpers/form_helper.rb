# frozen_string_literal: true

module V7CMS
  module FormHelper
    extend self # rubocop:disable Style/ModuleFunction

    def render_form(slug)
      form = V7CMS::Form.published.includes(:form_fields).find_by(slug: slug)
      return '' unless form

      V7CMS::FormRenderer.render(form)
    end

    def process_form_shortcodes(content)
      return content if content.nil?

      cache = {}
      content.gsub(/\[form:([a-z0-9-]+)\]/) do
        slug = ::Regexp.last_match(1)
        cache[slug] ||= render_form(slug)
      end
    end
  end
end
