require 'spec_helper'

RSpec.describe Theme, type: :model do
  # Mock callbacks to prevent actual file generation during tests
  before do
    allow_any_instance_of(Theme).to receive(:regenerate_theme_css)
    allow_any_instance_of(Theme).to receive(:regenerate_all_static_files)
  end

  describe '.instance' do
    it 'returns a theme record' do
      theme = Theme.instance
      expect(theme).to be_a(Theme)
      expect(theme).to be_persisted
    end

    it 'returns the same record on multiple calls' do
      first = Theme.instance
      second = Theme.instance
      expect(first.id).to eq(second.id)
    end

    it 'creates a theme record if none exists' do
      expect(Theme.count).to eq(0)
      Theme.instance
      expect(Theme.count).to eq(1)
    end

    it 'creates theme with active flag set to true' do
      theme = Theme.instance
      expect(theme.active).to be true
    end
  end

  describe 'default values' do
    let(:theme) { Theme.instance }

    describe 'color fields' do
      it 'has default primary_color' do
        expect(theme.primary_color).to eq('#3b82f6')
      end

      it 'has default secondary_color' do
        expect(theme.secondary_color).to eq('#8b5cf6')
      end

      it 'has default background_color' do
        expect(theme.background_color).to eq('#ffffff')
      end

      it 'has default text_color' do
        expect(theme.text_color).to eq('#1f2937')
      end

      it 'has default heading_color' do
        expect(theme.heading_color).to eq('#111827')
      end

      it 'has default link_color' do
        expect(theme.link_color).to eq('#2563eb')
      end

      it 'has default link_hover_color' do
        expect(theme.link_hover_color).to eq('#1d4ed8')
      end

      it 'has default border_color' do
        expect(theme.border_color).to eq('#e5e7eb')
      end
    end

    describe 'typography fields' do
      it 'has default font_heading' do
        expect(theme.font_heading).to eq('system-ui, -apple-system, sans-serif')
      end

      it 'has default font_body' do
        expect(theme.font_body).to eq('system-ui, -apple-system, sans-serif')
      end

      it 'has default font_size_base' do
        expect(theme.font_size_base).to eq(16)
      end

      it 'has default line_height' do
        expect(theme.line_height).to eq(1.6)
      end
    end

    describe 'layout fields' do
      it 'has default layout_width' do
        expect(theme.layout_width).to eq('standard')
      end

      it 'has default layout_style' do
        expect(theme.layout_style).to eq('boxed')
      end

      it 'has default spacing_scale' do
        expect(theme.spacing_scale).to eq(1.0)
      end

      it 'has default border_radius' do
        expect(theme.border_radius).to eq('medium')
      end
    end

    describe 'advanced fields' do
      it 'has default custom_css as nil' do
        expect(theme.custom_css).to be_nil
      end

      it 'has default header_style' do
        expect(theme.header_style).to eq('default')
      end

      it 'has default footer_style' do
        expect(theme.footer_style).to eq('default')
      end
    end
  end

  describe 'validations' do
    let(:theme) { Theme.instance }

    describe 'color validations' do
      it 'accepts valid 6-character hex colors' do
        theme.primary_color = '#ff0000'
        expect(theme).to be_valid
      end

      it 'accepts valid 3-character hex colors' do
        theme.primary_color = '#f00'
        expect(theme).to be_valid
      end

      it 'accepts lowercase hex colors' do
        theme.primary_color = '#abc123'
        expect(theme).to be_valid
      end

      it 'accepts uppercase hex colors' do
        theme.primary_color = '#ABC123'
        expect(theme).to be_valid
      end

      it 'rejects colors without hash prefix' do
        theme.primary_color = 'ff0000'
        expect(theme).not_to be_valid
        expect(theme.errors[:primary_color]).to include('must be a valid hex color')
      end

      it 'rejects colors with invalid characters' do
        theme.primary_color = '#gggggg'
        expect(theme).not_to be_valid
        expect(theme.errors[:primary_color]).to include('must be a valid hex color')
      end

      it 'rejects colors with wrong length' do
        theme.primary_color = '#ff00'
        expect(theme).not_to be_valid
        expect(theme.errors[:primary_color]).to include('must be a valid hex color')
      end

      it 'rejects blank primary_color' do
        theme.primary_color = ''
        expect(theme).not_to be_valid
      end

      it 'rejects blank secondary_color' do
        theme.secondary_color = ''
        expect(theme).not_to be_valid
      end

      it 'rejects blank background_color' do
        theme.background_color = ''
        expect(theme).not_to be_valid
      end

      it 'rejects blank text_color' do
        theme.text_color = ''
        expect(theme).not_to be_valid
      end

      it 'rejects blank heading_color' do
        theme.heading_color = ''
        expect(theme).not_to be_valid
      end

      it 'rejects blank link_color' do
        theme.link_color = ''
        expect(theme).not_to be_valid
      end

      it 'rejects blank link_hover_color' do
        theme.link_hover_color = ''
        expect(theme).not_to be_valid
      end

      it 'rejects blank border_color' do
        theme.border_color = ''
        expect(theme).not_to be_valid
      end
    end

    describe 'numeric validations' do
      describe 'font_size_base' do
        it 'accepts value of 14' do
          theme.font_size_base = 14
          expect(theme).to be_valid
        end

        it 'accepts value of 20' do
          theme.font_size_base = 20
          expect(theme).to be_valid
        end

        it 'rejects value less than 14' do
          theme.font_size_base = 13
          expect(theme).not_to be_valid
          expect(theme.errors[:font_size_base]).to include('must be greater than or equal to 14')
        end

        it 'rejects value greater than 20' do
          theme.font_size_base = 21
          expect(theme).not_to be_valid
          expect(theme.errors[:font_size_base]).to include('must be less than or equal to 20')
        end

        it 'rejects non-integer values' do
          theme.font_size_base = 16.5
          expect(theme).not_to be_valid
          expect(theme.errors[:font_size_base]).to include('must be an integer')
        end
      end

      describe 'line_height' do
        it 'accepts value of 1.4' do
          theme.line_height = 1.4
          expect(theme).to be_valid
        end

        it 'accepts value of 2.0' do
          theme.line_height = 2.0
          expect(theme).to be_valid
        end

        it 'rejects value less than 1.4' do
          theme.line_height = 1.3
          expect(theme).not_to be_valid
          expect(theme.errors[:line_height]).to include('must be greater than or equal to 1.4')
        end

        it 'rejects value greater than 2.0' do
          theme.line_height = 2.1
          expect(theme).not_to be_valid
          expect(theme.errors[:line_height]).to include('must be less than or equal to 2.0')
        end

        it 'accepts decimal values' do
          theme.line_height = 1.75
          expect(theme).to be_valid
        end
      end

      describe 'spacing_scale' do
        it 'accepts value of 0.75' do
          theme.spacing_scale = 0.75
          expect(theme).to be_valid
        end

        it 'accepts value of 1.5' do
          theme.spacing_scale = 1.5
          expect(theme).to be_valid
        end

        it 'rejects value less than 0.75' do
          theme.spacing_scale = 0.74
          expect(theme).not_to be_valid
          expect(theme.errors[:spacing_scale]).to include('must be greater than or equal to 0.75')
        end

        it 'rejects value greater than 1.5' do
          theme.spacing_scale = 1.51
          expect(theme).not_to be_valid
          expect(theme.errors[:spacing_scale]).to include('must be less than or equal to 1.5')
        end

        it 'accepts decimal values' do
          theme.spacing_scale = 1.25
          expect(theme).to be_valid
        end
      end
    end

    describe 'enum validations' do
      describe 'layout_width' do
        it 'accepts valid values' do
          %w[full wide standard narrow].each do |value|
            theme.layout_width = value
            expect(theme).to be_valid
          end
        end

        it 'rejects invalid values' do
          theme.layout_width = 'invalid'
          expect(theme).not_to be_valid
          expect(theme.errors[:layout_width]).to include('is not included in the list')
        end
      end

      describe 'layout_style' do
        it 'accepts valid values' do
          %w[full-width boxed centered].each do |value|
            theme.layout_style = value
            expect(theme).to be_valid
          end
        end

        it 'rejects invalid values' do
          theme.layout_style = 'invalid'
          expect(theme).not_to be_valid
          expect(theme.errors[:layout_style]).to include('is not included in the list')
        end
      end

      describe 'border_radius' do
        it 'accepts valid values' do
          %w[none subtle medium large].each do |value|
            theme.border_radius = value
            expect(theme).to be_valid
          end
        end

        it 'rejects invalid values' do
          theme.border_radius = 'invalid'
          expect(theme).not_to be_valid
          expect(theme.errors[:border_radius]).to include('is not included in the list')
        end
      end

      describe 'header_style' do
        it 'accepts valid values' do
          %w[default minimal prominent].each do |value|
            theme.header_style = value
            expect(theme).to be_valid
          end
        end

        it 'rejects invalid values' do
          theme.header_style = 'invalid'
          expect(theme).not_to be_valid
          expect(theme.errors[:header_style]).to include('is not included in the list')
        end
      end

      describe 'footer_style' do
        it 'accepts valid values' do
          %w[default minimal detailed].each do |value|
            theme.footer_style = value
            expect(theme).to be_valid
          end
        end

        it 'rejects invalid values' do
          theme.footer_style = 'invalid'
          expect(theme).not_to be_valid
          expect(theme.errors[:footer_style]).to include('is not included in the list')
        end
      end
    end

    describe 'custom_css validation' do
      it 'accepts blank custom_css' do
        theme.custom_css = ''
        expect(theme).to be_valid
      end

      it 'accepts nil custom_css' do
        theme.custom_css = nil
        expect(theme).to be_valid
      end

      it 'accepts custom_css up to 10000 characters' do
        theme.custom_css = 'a' * 10000
        expect(theme).to be_valid
      end

      it 'rejects custom_css over 10000 characters' do
        theme.custom_css = 'a' * 10001
        expect(theme).not_to be_valid
        expect(theme.errors[:custom_css]).to include('is too long (maximum is 10000 characters)')
      end
    end
  end

  describe '#reset_to_defaults!' do
    it 'resets all fields to default values' do
      theme = Theme.instance
      theme.update!(
        primary_color: '#000000',
        secondary_color: '#111111',
        background_color: '#222222',
        text_color: '#333333',
        heading_color: '#444444',
        link_color: '#555555',
        link_hover_color: '#666666',
        border_color: '#777777',
        font_heading: 'Arial',
        font_body: 'Helvetica',
        font_size_base: 18,
        line_height: 1.8,
        layout_width: 'wide',
        layout_style: 'centered',
        spacing_scale: 1.2,
        border_radius: 'large',
        custom_css: '.test { color: red; }',
        header_style: 'prominent',
        footer_style: 'detailed'
      )

      theme.reset_to_defaults!

      # Reload to get fresh data
      theme.reload

      expect(theme.primary_color).to eq('#3b82f6')
      expect(theme.secondary_color).to eq('#8b5cf6')
      expect(theme.background_color).to eq('#ffffff')
      expect(theme.text_color).to eq('#1f2937')
      expect(theme.heading_color).to eq('#111827')
      expect(theme.link_color).to eq('#2563eb')
      expect(theme.link_hover_color).to eq('#1d4ed8')
      expect(theme.border_color).to eq('#e5e7eb')
      expect(theme.font_heading).to eq('system-ui, -apple-system, sans-serif')
      expect(theme.font_body).to eq('system-ui, -apple-system, sans-serif')
      expect(theme.font_size_base).to eq(16)
      expect(theme.line_height).to eq(1.6)
      expect(theme.layout_width).to eq('standard')
      expect(theme.layout_style).to eq('boxed')
      expect(theme.spacing_scale).to eq(1.0)
      expect(theme.border_radius).to eq('medium')
      expect(theme.custom_css).to be_nil
      expect(theme.header_style).to eq('default')
      expect(theme.footer_style).to eq('default')
    end
  end

  describe 'callbacks' do
    it 'calls regenerate_theme_css after commit' do
      theme = Theme.instance
      expect(theme).to receive(:regenerate_theme_css)
      theme.update!(primary_color: '#ff0000')
    end

    it 'calls regenerate_all_static_files after commit' do
      theme = Theme.instance
      expect(theme).to receive(:regenerate_all_static_files)
      theme.update!(primary_color: '#ff0000')
    end
  end
end
