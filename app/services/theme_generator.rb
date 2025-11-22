require_relative '../config/theme_fields'

class ThemeGenerator
  # Generate and write theme CSS (for non-CDN/compiled mode)
  def self.generate_and_write(theme)
    css = new(theme).generate_css
    path = File.join(File.dirname(__FILE__), '..', '..', 'public', 'css', 'theme.css')
    FileUtils.mkdir_p(File.dirname(path))
    File.write(path, css)
    path
  end

  # Generate input.css for Tailwind CLI compilation
  def self.generate_input_css(theme)
    new(theme).generate_input_css
  end

  def initialize(theme)
    @theme = theme
  end

  # Generate standalone CSS file (current approach - used when theme.css is linked)
  def generate_css
    <<~CSS
      /* Generated theme CSS - uses CSS custom properties */
      :root {
#{generate_theme_variables}
      }

      /* Apply theme variables to elements */
      body {
        font-family: var(--font-body);
        font-size: var(--font-size-base);
        line-height: var(--line-height-base);
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
        max-width: var(--container-max);
      }

      .border, hr {
        border-color: var(--color-border);
      }

      /* Custom CSS */
      #{@theme.custom_css}
    CSS
  end

  # Generate input.css for Tailwind CLI (future compiled mode)
  def generate_input_css
    <<~CSS
      @tailwind base;
      @tailwind components;
      @tailwind utilities;

      @theme {
#{generate_theme_variables}
      }

      /* Custom CSS */
      #{@theme.custom_css}
    CSS
  end

  private

  def generate_theme_variables
    ThemeConfig::FIELDS.map do |field, config|
      value = @theme.send(field)
      next if value.nil?

      formatted_value = ThemeConfig.format_value(field, value)
      "  #{config[:css_var]}: #{formatted_value};"
    end.compact.join("\n")
  end
end
