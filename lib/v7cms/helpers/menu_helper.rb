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
      links = items.map do |item|
        target_attr = item.target.present? ? " target=\"#{h(item.target)}\"" : ''
        "<a href=\"#{h(item.href)}\" class=\"text-gray-600 hover:text-gray-900 transition\"#{target_attr}>#{h(item.label)}</a>"
      end
      "<nav class=\"flex flex-wrap gap-x-4 gap-y-2 justify-center text-sm mb-3\">#{links.join("\n")}</nav>"
    end

    def render_nav_item(item)
      target_attr = item.target.present? ? " target=\"#{h(item.target)}\"" : ''
      children = item.children.includes(:linkable)

      if children.any?
        child_links = children.map do |child|
          child_target = child.target.present? ? " target=\"#{h(child.target)}\"" : ''
          "<a href=\"#{h(child.href)}\" class=\"block px-4 py-2 text-sm text-gray-700 hover:bg-gray-100 transition\"#{child_target}>#{h(child.label)}</a>"
        end.join("\n")

        <<~HTML
          <div class="relative group">
            <a href="#{h(item.href)}" class="text-gray-600 hover:text-gray-900 transition"#{target_attr}>#{h(item.label)}</a>
            <div class="hidden group-hover:block absolute left-0 top-full mt-1 bg-white border border-gray-200 rounded-lg shadow-lg py-1 min-w-[160px] z-50">
              #{child_links}
            </div>
          </div>
        HTML
      else
        "<a href=\"#{h(item.href)}\" class=\"text-gray-600 hover:text-gray-900 transition\"#{target_attr}>#{h(item.label)}</a>"
      end
    end

    def h(str)
      CGI.escapeHTML(str.to_s)
    end
  end
end
