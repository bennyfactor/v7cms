class AddFullSlugPathToPages < ActiveRecord::Migration[7.0]
  def change
    add_column :pages, :full_slug_path, :string
    add_index :pages, :full_slug_path
  end
end
