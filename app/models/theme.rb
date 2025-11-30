require_relative '../../config/theme_fields'

class Theme < ActiveRecord::Base
  # Singleton pattern - only one theme record exists
  def self.instance
    first_or_create!(active: true)
  end

  # Validations - dynamically generated from ThemeConfig
  # Validate all color fields
  ThemeConfig.fields_by_type(:color).each do |field|
    validates field,
              format: { with: /\A#(?:[0-9a-fA-F]{3}){1,2}\z/, message: 'must be a valid hex color' },
              allow_blank: false
  end

  # Validate numeric fields
  validates :font_size_base, numericality: { only_integer: true, greater_than_or_equal_to: 12, less_than_or_equal_to: 24 }
  validates :line_height_base, :line_height_tight, :line_height_loose,
            numericality: { greater_than_or_equal_to: 1.0, less_than_or_equal_to: 2.5 }
  validates :spacing_unit, :spacing_section,
            numericality: { greater_than_or_equal_to: 0.25, less_than_or_equal_to: 10.0 }

  # Validate enum fields
  validates :layout_width, inclusion: { in: %w[full wide standard narrow] }
  validates :header_style, inclusion: { in: %w[default minimal prominent] }
  validates :footer_style, inclusion: { in: %w[default minimal centered] }

  # Validate string lengths
  validates :font_heading, :font_body, :font_mono, length: { maximum: 200 }, allow_blank: true
  validates :radius_sm, :radius_default, :radius_lg, :border_width, length: { maximum: 20 }, allow_blank: true
  validates :shadow_sm, :shadow_default, :shadow_lg, length: { maximum: 500 }, allow_blank: true
  validates :custom_css, length: { maximum: 10000 }, allow_blank: true

  # Callbacks
  after_commit :regenerate_theme_css
  after_commit :regenerate_all_static_files

  # Reset to default values using ThemeConfig
  def reset_to_defaults!
    defaults = ThemeConfig::FIELDS.transform_values { |config| config[:default] }
    update!(defaults)
  end

  private

  def regenerate_theme_css
    require_relative '../services/theme_generator'
    ThemeGenerator.generate_and_write(self)
  end

  def regenerate_all_static_files
    require_relative '../services/post_renderer'
    require_relative '../services/page_renderer'

    Post.published.find_each { |post| PostRenderer.write_static_file(post) }
    Page.published.find_each { |page| PageRenderer.write_static_file(page) }
  end
end
