# frozen_string_literal: true

require 'swagger/blocks'

class ThemeSchemas
  include Swagger::Blocks

  swagger_schema :Theme do
    key :type, :object
    key :description, 'Theme customization settings with 40+ configurable fields'

    # Brand colors
    property :primary_color do
      key :type, :string
      key :pattern, '^#[0-9A-Fa-f]{6}$'
    end
    property :primary_hover_color do
      key :type, :string
      key :pattern, '^#[0-9A-Fa-f]{6}$'
    end
    property :secondary_color do
      key :type, :string
      key :pattern, '^#[0-9A-Fa-f]{6}$'
    end
    property :secondary_hover_color do
      key :type, :string
      key :pattern, '^#[0-9A-Fa-f]{6}$'
    end

    # Neutrals
    property :background_color do
      key :type, :string
      key :pattern, '^#[0-9A-Fa-f]{6}$'
    end
    property :surface_color do
      key :type, :string
      key :pattern, '^#[0-9A-Fa-f]{6}$'
    end
    property :surface_hover_color do
      key :type, :string
      key :pattern, '^#[0-9A-Fa-f]{6}$'
    end

    # Text
    property :text_color do
      key :type, :string
      key :pattern, '^#[0-9A-Fa-f]{6}$'
    end
    property :text_muted_color do
      key :type, :string
      key :pattern, '^#[0-9A-Fa-f]{6}$'
    end
    property :heading_color do
      key :type, :string
      key :pattern, '^#[0-9A-Fa-f]{6}$'
    end

    # Links
    property :link_color do
      key :type, :string
      key :pattern, '^#[0-9A-Fa-f]{6}$'
    end
    property :link_hover_color do
      key :type, :string
      key :pattern, '^#[0-9A-Fa-f]{6}$'
    end

    # UI States
    property :border_color do
      key :type, :string
      key :pattern, '^#[0-9A-Fa-f]{6}$'
    end
    property :success_color do
      key :type, :string
      key :pattern, '^#[0-9A-Fa-f]{6}$'
    end
    property :warning_color do
      key :type, :string
      key :pattern, '^#[0-9A-Fa-f]{6}$'
    end
    property :error_color do
      key :type, :string
      key :pattern, '^#[0-9A-Fa-f]{6}$'
    end

    # Typography
    property :font_heading do
      key :type, :string
    end
    property :font_body do
      key :type, :string
    end
    property :font_mono do
      key :type, :string
    end
    property :font_size_base do
      key :type, :integer
      key :minimum, 12
      key :maximum, 24
    end
    property :line_height_base do
      key :type, :number
      key :minimum, 1.0
      key :maximum, 2.5
    end

    # Layout
    property :layout_width do
      key :type, :string
      key :enum, ['narrow', 'standard', 'wide', 'full']
    end
    property :spacing_unit do
      key :type, :number
    end
    property :spacing_section do
      key :type, :number
    end

    # Effects
    property :radius_sm do
      key :type, :string
    end
    property :radius_default do
      key :type, :string
    end
    property :radius_lg do
      key :type, :string
    end
    property :border_width do
      key :type, :string
    end
    property :shadow_sm do
      key :type, :string
    end
    property :shadow_default do
      key :type, :string
    end
    property :shadow_lg do
      key :type, :string
    end

    # Advanced
    property :header_style do
      key :type, :string
      key :enum, ['default', 'minimal', 'prominent']
    end
    property :footer_style do
      key :type, :string
      key :enum, ['default', 'minimal', 'centered']
    end
    property :custom_css do
      key :type, :string
      key :maxLength, 10000
    end
  end

  swagger_schema :ThemeResponse do
    key :type, :object
    property :theme do
      key :'$ref', :Theme
    end
  end
end
