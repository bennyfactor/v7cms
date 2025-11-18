class AddForeignKeyToPages < ActiveRecord::Migration[8.1]
  def change
    # First, clean up any orphaned pages (parent_id pointing to non-existent pages)
    execute <<-SQL
      UPDATE pages
      SET parent_id = NULL
      WHERE parent_id IS NOT NULL
        AND parent_id NOT IN (SELECT id FROM pages)
    SQL

    # Add foreign key constraint
    add_foreign_key :pages, :pages, column: :parent_id, on_delete: :restrict
  end
end
