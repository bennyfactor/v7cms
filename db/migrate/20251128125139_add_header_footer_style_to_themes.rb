class AddHeaderFooterStyleToThemes < ActiveRecord::Migration[8.1]
  def change
    add_column :themes, :header_style, :string, default: 'default'
    add_column :themes, :footer_style, :string, default: 'default'
  end
end
