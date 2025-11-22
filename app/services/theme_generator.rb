class ThemeGenerator
  def self.generate_and_write(theme)
    css = new(theme).generate_css
    path = File.join(File.dirname(__FILE__), '..', '..', 'public', 'css', 'theme.css')
    FileUtils.mkdir_p(File.dirname(path))
    File.write(path, css)
    path
  end

  def initialize(theme)
    @theme = theme
  end

  def generate_css
    <<~CSS
      :root {
        /* Colors */
        --color-primary: #{@theme.primary_color};
        --color-secondary: #{@theme.secondary_color};
        --color-background: #{@theme.background_color};
        --color-text: #{@theme.text_color};
        --color-heading: #{@theme.heading_color};
        --color-link: #{@theme.link_color};
        --color-link-hover: #{@theme.link_hover_color};
        --color-border: #{@theme.border_color};

        /* Typography */
        --font-heading: #{@theme.font_heading};
        --font-body: #{@theme.font_body};
        --font-size-base: #{@theme.font_size_base}px;
        --line-height: #{@theme.line_height};

        /* Layout */
        --container-width: #{container_width_px};
        --spacing-unit: #{@theme.spacing_scale}rem;
        --border-radius: #{border_radius_px};
      }

      /* Apply variables to elements */
      body {
        font-family: var(--font-body);
        font-size: var(--font-size-base);
        line-height: var(--line-height);
        color: var(--color-text);
        background: var(--color-background);
      }

      h1, h2, h3, h4, h5, h6 {
        font-family: var(--font-heading);
        color: var(--color-heading);
      }

      a {
        color: var(--color-link);
      }

      a:hover {
        color: var(--color-link-hover);
      }

      .container {
        max-width: var(--container-width);
      }

      /* Borders */
      .border, hr {
        border-color: var(--color-border);
      }

      /* Buttons */
      .btn-primary {
        background-color: var(--color-primary);
        color: var(--color-background);
      }

      .btn-secondary {
        background-color: var(--color-secondary);
        color: var(--color-background);
      }

      /* Border radius */
      .rounded {
        border-radius: var(--border-radius);
      }

      /* Custom CSS */
      #{@theme.custom_css}
    CSS
  end

  private

  def container_width_px
    case @theme.layout_width
    when 'full' then '100%'
    when 'wide' then '1400px'
    when 'standard' then '1200px'
    when 'narrow' then '900px'
    else '1200px'
    end
  end

  def border_radius_px
    case @theme.border_radius
    when 'none' then '0'
    when 'subtle' then '4px'
    when 'medium' then '8px'
    when 'large' then '16px'
    else '8px'
    end
  end
end
