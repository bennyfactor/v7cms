# frozen_string_literal: true

class CreateContentVersions < ActiveRecord::Migration[7.0]
  def change
    create_table :content_versions do |t|
      t.string :versionable_type, null: false
      t.integer :versionable_id, null: false
      t.integer :version_number, null: false
      t.string :version_type, null: false, default: 'auto'
      t.string :workflow_state
      t.text :title
      t.text :content
      t.text :metadata
      t.references :created_by, foreign_key: { to_table: :users }
      t.datetime :expires_at
      t.datetime :created_at, null: false
    end

    add_index :content_versions, [:versionable_type, :versionable_id, :version_number],
              unique: true, name: 'idx_content_versions_unique'
    add_index :content_versions, :expires_at
  end
end
