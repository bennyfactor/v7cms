# frozen_string_literal: true

require 'cgi'

module V7CMS
  module MenuHelper
    module_function

    def render_menu(location_or_slug)
      menu = V7CMS::Menu.at_location(location_or_slug) || V7CMS::Menu.by_slug(location_or_slug)
      return '' unless menu

      items = menu.root_items.includes(children: :linkable, linkable: [])
      return '' if items.empty?

      if menu.location == 'footer'
        render_footer_menu(items)
      else
        render_nav_menu(items)
      end
    end

    def render_nav_menu(items)
      items.map { |item| render_nav_item(item) }.join("\n")
    end

    def render_footer_menu(items)
      links = items.map { |item| render_link(item, 'text-gray-600 hover:text-gray-900 transition') }
      "<nav class=\"flex flex-wrap gap-x-4 gap-y-2 justify-center text-sm mb-3\">#{links.join("\n")}</nav>"
    end

    def render_nav_item(item)
      children = item.children.includes(:linkable)

      if children.any?
        render_dropdown(item, children)
      else
        render_link(item, 'text-gray-600 hover:text-gray-900 transition')
      end
    end

    def render_dropdown(item, children)
      target_attr = target_attribute(item)
      child_links = children.map do |child|
        render_link(child, 'block px-4 py-2 text-sm text-gray-700 hover:bg-gray-100 transition')
      end.join("\n")

      <<~HTML
        <div class="relative group">
          <a href="#{h(item.href)}" class="text-gray-600 hover:text-gray-900 transition"#{target_attr}>#{h(item.label)}</a>
          <div class="hidden group-hover:block absolute left-0 top-full mt-1 bg-white border border-gray-200 rounded-lg shadow-lg py-1 min-w-[160px] z-50">
            #{child_links}
          </div>
        </div>
      HTML
    end

    def render_link(item, css_class)
      target_attr = target_attribute(item)
      "<a href=\"#{h(item.href)}\" class=\"#{css_class}\"#{target_attr}>#{h(item.label)}</a>"
    end

    def target_attribute(item)
      item.target.present? ? " target=\"#{h(item.target)}\"" : ''
    end

    def h(str)
      CGI.escapeHTML(str.to_s)
    end
  end
end
