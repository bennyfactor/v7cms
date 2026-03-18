# frozen_string_literal: true

class AddMenuItemsCountToMenus < ActiveRecord::Migration[7.0]
  class Menu < ActiveRecord::Base
    self.table_name = 'menus'
    has_many :menu_items, foreign_key: :menu_id
  end

  def change
    add_column :menus, :menu_items_count, :integer, default: 0, null: false

    reversible do |dir|
      dir.up do
        Menu.find_each do |menu|
          Menu.reset_counters(menu.id, :menu_items)
        end
      end
    end
  end
end
