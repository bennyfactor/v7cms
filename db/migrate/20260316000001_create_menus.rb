# frozen_string_literal: true

class CreateMenus < ActiveRecord::Migration[7.0]
  def change
    create_table :menus do |t|
      t.string :name, null: false
      t.string :slug, null: false
      t.string :location
      t.timestamps
    end

    add_index :menus, :slug, unique: true
    add_index :menus, :location, unique: true, where: 'location IS NOT NULL'

    create_table :menu_items do |t|
      t.references :menu, null: false, foreign_key: true
      t.references :parent, foreign_key: { to_table: :menu_items }
      t.string :label, null: false
      t.string :link_type, null: false, default: 'custom'
      t.string :linkable_type
      t.integer :linkable_id
      t.string :url
      t.string :target
      t.integer :position, default: 0
      t.timestamps
    end

    add_index :menu_items, %i[menu_id position]
    add_index :menu_items, %i[linkable_type linkable_id]

    reversible do |dir|
      dir.up do
        execute <<-SQL
          INSERT INTO menus (name, slug, location, created_at, updated_at)
          VALUES ('Main', 'main', 'header', datetime('now'), datetime('now'))
        SQL
        execute <<-SQL
          INSERT INTO menu_items (menu_id, label, link_type, url, position, created_at, updated_at)
          VALUES ((SELECT id FROM menus WHERE slug = 'main'), 'Home', 'custom', '/', 0, datetime('now'), datetime('now'))
        SQL
      end
    end
  end
end
