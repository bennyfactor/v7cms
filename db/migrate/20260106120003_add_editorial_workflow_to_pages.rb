# frozen_string_literal: true

class AddEditorialWorkflowToPages < ActiveRecord::Migration[7.0]
  def change
    add_column :pages, :status, :string, default: 'draft', null: false
    add_column :pages, :published_version_id, :integer, null: true

    add_index :pages, :status
    add_foreign_key :pages, :content_versions, column: :published_version_id, on_delete: :nullify
  end
end
