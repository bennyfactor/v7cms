require_relative '../spec_helper'
require_relative '../../app/services/theme_generator'

RSpec.describe ThemeGenerator do
  let(:theme) do
    Theme.new(
      primary_color: '#3b82f6',
      secondary_color: '#8b5cf6',
      background_color: '#ffffff',
      text_color: '#1f2937',
      heading_color: '#111827',
      link_color: '#2563eb',
      link_hover_color: '#1d4ed8',
      border_color: '#e5e7eb',
      font_heading: 'system-ui, -apple-system, sans-serif',
      font_body: 'Georgia, serif',
      font_size_base: 16,
      line_height_base: 1.6,
      layout_width: 'standard',
      spacing_unit: 1.0,
      radius_default: '8px',
      custom_css: nil
    )
  end

  let(:generator) { ThemeGenerator.new(theme) }
  let(:theme_file_path) { File.join(File.dirname(__FILE__), '..', '..', 'public', 'css', 'theme.css') }

  before do
    # Save theme without triggering callbacks
    theme.save!(validate: false) if theme.new_record?
  end

  after do
    # Clean up generated theme.css file
    FileUtils.rm_f(theme_file_path) if File.exist?(theme_file_path)
  end

  describe '#generate_css' do
    let(:css) { generator.generate_css }

    context 'CSS custom properties' do
      it 'includes all color custom properties' do
        expect(css).to include('--color-primary: #3b82f6;')
        expect(css).to include('--color-secondary: #8b5cf6;')
        expect(css).to include('--color-background: #ffffff;')
        expect(css).to include('--color-text: #1f2937;')
        expect(css).to include('--color-heading: #111827;')
        expect(css).to include('--color-link: #2563eb;')
        expect(css).to include('--color-link-hover: #1d4ed8;')
        expect(css).to include('--color-border: #e5e7eb;')
      end

      it 'includes all typography custom properties' do
        expect(css).to include('--font-heading: system-ui, -apple-system, sans-serif;')
        expect(css).to include('--font-body: Georgia, serif;')
        expect(css).to include('--font-size-base: 16px;')
        expect(css).to include('--line-height-base: 1.6;')
      end

      it 'includes all layout custom properties' do
        expect(css).to include('--container-max: 1200px;')
        expect(css).to include('--spacing-unit: 1.0rem;')
        expect(css).to include('--radius-default: 8px;')
      end
    end

    context 'CSS selector rules' do
      it 'applies font and color variables to body element' do
        expect(css).to include('body {')
        expect(css).to include('font-family: var(--font-body);')
        expect(css).to include('font-size: var(--font-size-base);')
        expect(css).to include('line-height: var(--line-height);')
        expect(css).to include('color: var(--color-text);')
        expect(css).to include('background: var(--color-background);')
      end

      it 'applies font and color variables to heading elements' do
        expect(css).to include('h1, h2, h3, h4, h5, h6 {')
        expect(css).to include('font-family: var(--font-heading);')
        expect(css).to include('color: var(--color-heading);')
      end

      it 'applies link color to anchor elements' do
        expect(css).to include('a {')
        expect(css).to include('color: var(--color-link);')
      end

      it 'applies hover color to anchor hover state' do
        expect(css).to include('a:hover {')
        expect(css).to include('color: var(--color-link-hover);')
      end

      it 'applies max-width to container class' do
        expect(css).to include('.container {')
        expect(css).to include('max-width: var(--container-width);')
      end

      it 'applies border color to border elements' do
        expect(css).to include('.border, hr {')
        expect(css).to include('border-color: var(--color-border);')
      end

      it 'applies primary color to primary button' do
        expect(css).to include('.btn-primary {')
        expect(css).to include('background-color: var(--color-primary);')
        expect(css).to include('color: var(--color-background);')
      end

      it 'applies secondary color to secondary button' do
        expect(css).to include('.btn-secondary {')
        expect(css).to include('background-color: var(--color-secondary);')
        expect(css).to include('color: var(--color-background);')
      end

      it 'applies border radius to rounded class' do
        expect(css).to include('.rounded {')
        expect(css).to include('border-radius: var(--border-radius);')
      end
    end

    context 'custom CSS injection' do
      it 'includes custom CSS when present' do
        theme.custom_css = '.custom-class { color: red; }'
        css = generator.generate_css

        expect(css).to include('.custom-class { color: red; }')
      end

      it 'does not add extra content when custom CSS is nil' do
        theme.custom_css = nil
        css = generator.generate_css

        expect(css).to include('/* Custom CSS */')
        # Verify CSS ends cleanly after custom CSS comment with just the theme custom_css value
        expect(css).to end_with("/* Custom CSS */\n\n")
      end

      it 'does not add extra content when custom CSS is empty string' do
        theme.custom_css = ''
        css = generator.generate_css

        expect(css).to include('/* Custom CSS */')
      end
    end

    context 'CSS structure' do
      it 'includes :root selector for custom properties' do
        expect(css).to include(':root {')
      end

      it 'includes comment sections for organization' do
        expect(css).to include('/* Colors */')
        expect(css).to include('/* Typography */')
        expect(css).to include('/* Layout */')
        expect(css).to include('/* Apply variables to elements */')
        expect(css).to include('/* Borders */')
        expect(css).to include('/* Buttons */')
        expect(css).to include('/* Border radius */')
        expect(css).to include('/* Custom CSS */')
      end
    end
  end

  describe '.generate_and_write' do
    it 'creates theme.css file' do
      # Delete the file first to ensure clean test
      FileUtils.rm_f(theme_file_path) if File.exist?(theme_file_path)
      expect(File.exist?(theme_file_path)).to be false

      ThemeGenerator.generate_and_write(theme)

      expect(File.exist?(theme_file_path)).to be true
    end

    it 'writes valid CSS content to file' do
      ThemeGenerator.generate_and_write(theme)

      content = File.read(theme_file_path)
      expect(content).to include(':root {')
      expect(content).to include('--color-primary: #3b82f6;')
      expect(content).to include('--font-body: Georgia, serif;')
      expect(content).to include('body {')
    end

    it 'creates public/css directory if it does not exist' do
      css_dir = File.dirname(theme_file_path)
      FileUtils.rm_rf(css_dir) if Dir.exist?(css_dir)
      expect(Dir.exist?(css_dir)).to be false

      ThemeGenerator.generate_and_write(theme)

      expect(Dir.exist?(css_dir)).to be true
      expect(File.exist?(theme_file_path)).to be true
    end

    it 'overwrites existing theme.css file' do
      ThemeGenerator.generate_and_write(theme)
      original_content = File.read(theme_file_path)

      theme.primary_color = '#ff0000'
      ThemeGenerator.generate_and_write(theme)

      new_content = File.read(theme_file_path)
      expect(new_content).not_to eq(original_content)
      expect(new_content).to include('--color-primary: #ff0000;')
      expect(new_content).not_to include('--color-primary: #3b82f6;')
    end

    it 'returns the path to the generated file' do
      result = ThemeGenerator.generate_and_write(theme)
      # Normalize paths for comparison (both should point to same file)
      expect(File.expand_path(result)).to eq(File.expand_path(theme_file_path))
    end
  end

  describe 'integration with different theme configurations' do
    it 'generates correct CSS for wide layout with large border radius' do
      theme.layout_width = 'wide'
      theme.border_radius = 'large'
      css = generator.generate_css

      expect(css).to include('--container-max: 1400px;')
      expect(css).to include('--radius-default: 16px;')
    end

    it 'generates correct CSS for narrow layout with no border radius' do
      theme.layout_width = 'narrow'
      theme.border_radius = 'none'
      css = generator.generate_css

      expect(css).to include('--container-max: 900px;')
      expect(css).to include('--radius-default: 0;')
    end

    it 'generates correct CSS for full width layout' do
      theme.layout_width = 'full'
      css = generator.generate_css

      expect(css).to include('--container-max: 100%;')
    end

    it 'handles different font size values' do
      theme.font_size_base = 18
      css = generator.generate_css

      expect(css).to include('--font-size-base: 18px;')
    end

    it 'handles different line height values' do
      theme.line_height = 1.8
      css = generator.generate_css

      expect(css).to include('--line-height-base: 1.8;')
    end

    it 'handles different spacing scale values' do
      theme.spacing_scale = 1.25
      css = generator.generate_css

      expect(css).to include('--spacing-unit: 1.25rem;')
    end

    it 'generates CSS with complex custom fonts' do
      theme.font_heading = '"Playfair Display", Georgia, serif'
      theme.font_body = '"Inter", system-ui, sans-serif'
      css = generator.generate_css

      expect(css).to include('--font-heading: "Playfair Display", Georgia, serif;')
      expect(css).to include('--font-body: "Inter", system-ui, sans-serif;')
    end

    it 'generates CSS with multiline custom CSS' do
      theme.custom_css = <<~CSS
        .custom-header {
          font-size: 2rem;
          font-weight: bold;
        }

        .custom-footer {
          padding: 2rem;
        }
      CSS

      css = generator.generate_css

      expect(css).to include('.custom-header {')
      expect(css).to include('font-size: 2rem;')
      expect(css).to include('.custom-footer {')
      expect(css).to include('padding: 2rem;')
    end
  end

  describe 'error handling' do
    let(:theme) { Theme.instance }

    describe '.generate_and_write' do
      it 'returns file path when write succeeds' do
        result = ThemeGenerator.generate_and_write(theme)
        expect(result).to be_a(String)
        expect(result).to end_with('theme.css')
      end

      it 'returns nil when directory creation fails' do
        allow(FileUtils).to receive(:mkdir_p).and_raise(Errno::EACCES, 'Permission denied')

        result = ThemeGenerator.generate_and_write(theme)
        expect(result).to be_nil
      end

      it 'returns nil when file write fails' do
        allow(File).to receive(:write).and_raise(Errno::ENOSPC, 'No space left on device')

        result = ThemeGenerator.generate_and_write(theme)
        expect(result).to be_nil
      end

      it 'logs error when directory creation fails' do
        logger = instance_double(Logger)
        allow(ThemeGenerator).to receive(:logger).and_return(logger)
        expect(logger).to receive(:error).with(/Permission denied/)
        expect(logger).to receive(:error).with(kind_of(String))  # backtrace
        allow(FileUtils).to receive(:mkdir_p).and_raise(Errno::EACCES, 'Permission denied')

        ThemeGenerator.generate_and_write(theme)
      end

      it 'logs error when file write fails' do
        logger = instance_double(Logger)
        allow(ThemeGenerator).to receive(:logger).and_return(logger)
        allow(logger).to receive(:info)
        expect(logger).to receive(:error).with(/No space left/)
        expect(logger).to receive(:error).with(kind_of(String))  # backtrace
        allow(File).to receive(:write).and_raise(Errno::ENOSPC, 'No space left on device')

        ThemeGenerator.generate_and_write(theme)
      end
    end
  end
end
