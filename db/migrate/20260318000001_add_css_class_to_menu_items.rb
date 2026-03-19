# frozen_string_literal: true

class AddCssClassToMenuItems < ActiveRecord::Migration[7.0]
  def change
    add_column :menu_items, :css_class, :string
  end
end
