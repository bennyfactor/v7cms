class AddDynamicContentToPages < ActiveRecord::Migration[8.1]
  def change
    add_column :pages, :content_source, :string, default: 'children'
    add_column :pages, :items_limit, :integer, default: 10
  end
end
