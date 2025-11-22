class Theme < ActiveRecord::Base
  # Singleton pattern - only one theme record exists
  def self.instance
    first_or_create!(active: true)
  end

  # Validations
  validates :primary_color, :secondary_color, :background_color, :text_color,
            :heading_color, :link_color, :link_hover_color, :border_color,
            format: { with: /\A#(?:[0-9a-fA-F]{3}){1,2}\z/, message: 'must be a valid hex color' },
            allow_blank: false

  validates :font_size_base, numericality: { only_integer: true, greater_than_or_equal_to: 14, less_than_or_equal_to: 20 }
  validates :line_height, numericality: { greater_than_or_equal_to: 1.4, less_than_or_equal_to: 2.0 }
  validates :spacing_scale, numericality: { greater_than_or_equal_to: 0.75, less_than_or_equal_to: 1.5 }

  validates :layout_width, inclusion: { in: %w[full wide standard narrow] }
  validates :layout_style, inclusion: { in: %w[full-width boxed centered] }
  validates :border_radius, inclusion: { in: %w[none subtle medium large] }
  validates :header_style, inclusion: { in: %w[default minimal prominent] }
  validates :footer_style, inclusion: { in: %w[default minimal detailed] }

  validates :custom_css, length: { maximum: 10000 }, allow_blank: true

  # Callbacks
  after_commit :regenerate_theme_css
  after_commit :regenerate_all_static_files

  # Reset to default values
  def reset_to_defaults!
    update!(
      primary_color: '#3b82f6',
      secondary_color: '#8b5cf6',
      background_color: '#ffffff',
      text_color: '#1f2937',
      heading_color: '#111827',
      link_color: '#2563eb',
      link_hover_color: '#1d4ed8',
      border_color: '#e5e7eb',
      font_heading: 'system-ui, -apple-system, sans-serif',
      font_body: 'system-ui, -apple-system, sans-serif',
      font_size_base: 16,
      line_height: 1.6,
      layout_width: 'standard',
      layout_style: 'boxed',
      spacing_scale: 1.0,
      border_radius: 'medium',
      custom_css: nil,
      header_style: 'default',
      footer_style: 'default'
    )
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
