class CreateTags < ActiveRecord::Migration[8.1]
  def change
    create_table :tags do |t|
      t.string :name, null: false
      t.string :slug, null: false
      t.timestamps
    end

    add_index :tags, 'name COLLATE NOCASE', unique: true, name: 'index_tags_on_name'
    add_index :tags, :slug, unique: true
  end
end
