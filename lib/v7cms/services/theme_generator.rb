# frozen_string_literal: true

require 'logger'
require 'fileutils'
require_relative '../config/theme_fields'

module V7CMS
  class ThemeGenerator
    def self.logger
      @logger ||= Logger.new(STDOUT)
    end

    # Generate and write theme CSS (for non-CDN/compiled mode)
    def self.generate_and_write(theme)
      begin
        css = new(theme).generate_css
        path = File.join(File.dirname(__FILE__), '..', '..', '..', 'public', 'css', 'theme.css')
        FileUtils.mkdir_p(File.dirname(path))
        File.write(path, css)
        logger.info("Generated theme CSS")
        path
      rescue => e
        logger.error("Failed to generate theme CSS: #{e.message}")
        logger.error(e.backtrace.join("\n"))
        nil
      end
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
      # Note: This requires config/theme_fields.rb to be loaded
      # which defines ThemeConfig::FIELDS
      return "" unless defined?(ThemeConfig)

      ThemeConfig::FIELDS.map do |field, config|
        value = @theme.send(field)
        next if value.nil?
        next if config[:css_var].nil? # Skip fields without CSS variables (e.g., custom_css)

        formatted_value = ThemeConfig.format_value(field, value)
        "  #{config[:css_var]}: #{formatted_value};"
      end.compact.join("\n")
    end
  end
end
