class CreateThemes < ActiveRecord::Migration[8.1]
  def change
    create_table :themes do |t|
      # Singleton flag
      t.boolean :active, default: true, null: false

      # Color fields (8)
      t.string :primary_color, default: '#3b82f6'
      t.string :secondary_color, default: '#8b5cf6'
      t.string :background_color, default: '#ffffff'
      t.string :text_color, default: '#1f2937'
      t.string :heading_color, default: '#111827'
      t.string :link_color, default: '#2563eb'
      t.string :link_hover_color, default: '#1d4ed8'
      t.string :border_color, default: '#e5e7eb'

      # Typography fields (4)
      t.string :font_heading, default: 'system-ui, -apple-system, sans-serif'
      t.string :font_body, default: 'system-ui, -apple-system, sans-serif'
      t.integer :font_size_base, default: 16
      t.decimal :line_height, default: 1.6, precision: 3, scale: 2

      # Layout fields (4)
      t.string :layout_width, default: 'standard'
      t.string :layout_style, default: 'boxed'
      t.decimal :spacing_scale, default: 1.0, precision: 3, scale: 2
      t.string :border_radius, default: 'medium'

      # Advanced fields (3)
      t.text :custom_css
      t.string :header_style, default: 'default'
      t.string :footer_style, default: 'default'

      t.timestamps
    end
  end
end
