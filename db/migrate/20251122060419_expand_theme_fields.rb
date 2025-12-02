require_relative '../../lib/v7cms/config/theme_fields'

class ExpandThemeFields < ActiveRecord::Migration[8.1]
  def up
    # Add all new theme fields from ThemeConfig
    # Existing fields will be skipped automatically

    ThemeConfig::FIELDS.each do |field_name, config|
      # Skip if column already exists
      next if column_exists?(:themes, field_name)

      case config[:type]
      when :color, :string, :enum
        add_column :themes, field_name, :string, default: config[:default]
      when :integer
        add_column :themes, field_name, :integer, default: config[:default]
      when :decimal
        add_column :themes, field_name, :decimal, precision: 3, scale: 2, default: config[:default]
      when :text
        add_column :themes, field_name, :text, default: config[:default]
      end
    end

    # Remove old fields that were renamed or replaced
    remove_old_fields_if_exist
  end

  def down
    # Only remove fields that didn't exist before this migration
    # Keep the original 19 fields intact
    original_fields = [
      :active, :primary_color, :secondary_color, :background_color, :text_color,
      :heading_color, :link_color, :link_hover_color, :border_color,
      :font_heading, :font_body, :font_size_base, :line_height,
      :layout_width, :layout_style, :spacing_scale, :border_radius,
      :custom_css, :header_style, :footer_style
    ]

    ThemeConfig::FIELDS.keys.each do |field_name|
      next if original_fields.include?(field_name)
      next unless column_exists?(:themes, field_name)

      remove_column :themes, field_name
    end
  end

  private

  def remove_old_fields_if_exist
    # Remove old fields that have been replaced with new semantic names
    old_fields_to_remove = [:line_height, :layout_style, :header_style, :footer_style]

    old_fields_to_remove.each do |field|
      remove_column :themes, field if column_exists?(:themes, field)
    end
  end
end
