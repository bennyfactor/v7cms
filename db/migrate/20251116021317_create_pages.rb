class CreatePages < ActiveRecord::Migration[8.1]
  def change
    create_table :pages do |t|
      t.string :title, null: false
      t.string :slug, null: false
      t.text :content
      t.integer :parent_id
      t.integer :position, default: 0
      t.string :page_type, default: 'standard'
      t.boolean :published, default: false

      t.timestamps
    end

    add_index :pages, :slug, unique: true
    add_index :pages, :parent_id
    add_index :pages, :position
    add_index :pages, :published
  end
end
