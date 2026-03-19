# frozen_string_literal: true

class AddMenuItemsCountToMenus < ActiveRecord::Migration[7.0]
  def change
    add_column :menus, :menu_items_count, :integer, default: 0, null: false

    reversible do |dir|
      dir.up do
        execute <<-SQL.squish
          UPDATE menus SET menu_items_count = (
            SELECT COUNT(*) FROM menu_items WHERE menu_items.menu_id = menus.id
          )
        SQL
      end
    end
  end
end
