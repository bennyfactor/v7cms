# frozen_string_literal: true

class CreateAssets < ActiveRecord::Migration[7.0]
  def change
    create_table :assets do |t|
      t.string :filename, null: false
      t.string :original_filename, null: false
      t.string :content_type, null: false
      t.integer :file_size, null: false
      t.string :storage_key, null: false
      t.integer :width
      t.integer :height
      t.string :alt_text
      t.references :uploaded_by, foreign_key: { to_table: :users }
      t.timestamps
    end

    add_index :assets, :storage_key, unique: true
    add_index :assets, :content_type
    add_index :assets, :created_at
  end
end
