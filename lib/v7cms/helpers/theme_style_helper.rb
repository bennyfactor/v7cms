# frozen_string_literal: true

module V7CMS
  # Maps Theme#header_style and Theme#footer_style to the Tailwind classes
  # shared by the dynamic layout (views/layout.erb) and the pre-baked static
  # HTML (PostRenderer/PageRenderer), so a theme change regenerates static
  # files that match the dynamic pages.
  module ThemeStyleHelper
    # respond_to? guards keep backward compatibility with databases that
    # predate the header_style/footer_style columns.
    def theme_header_style(theme)
      theme.respond_to?(:header_style) ? theme.header_style : 'default'
    end

    def theme_footer_style(theme)
      theme.respond_to?(:footer_style) ? theme.footer_style : 'default'
    end

    def header_classes(style)
      case style
      when 'minimal' then 'bg-white border-b'
      when 'prominent' then 'bg-white shadow-lg'
      else 'bg-white shadow-sm'
      end
    end

    def header_padding(style)
      case style
      when 'minimal' then 'py-3'
      when 'prominent' then 'py-8'
      else 'py-6'
      end
    end

    def header_title_size(style)
      style == 'prominent' ? 'text-3xl' : 'text-2xl'
    end

    def show_tagline?(style)
      style != 'minimal'
    end

    def footer_classes(_style)
      'bg-white border-t'
    end

    def footer_padding(style)
      case style
      when 'minimal' then 'py-3'
      when 'centered' then 'py-4'
      else 'py-6'
      end
    end

    def footer_text_size(style)
      style == 'minimal' ? 'text-xs' : 'text-sm'
    end
  end
end
