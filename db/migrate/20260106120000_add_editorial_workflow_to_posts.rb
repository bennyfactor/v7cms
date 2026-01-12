# frozen_string_literal: true

class AddEditorialWorkflowToPosts < ActiveRecord::Migration[7.0]
  def change
    add_column :posts, :status, :string, default: 'draft', null: false
    add_column :posts, :published_version_id, :integer, null: true

    add_index :posts, :status
    add_foreign_key :posts, :content_versions, column: :published_version_id, on_delete: :nullify
  end
end
