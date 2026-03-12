class AddContentFilterTagIdToPages < ActiveRecord::Migration[8.1]
  def change
    add_reference :pages, :content_filter_tag, foreign_key: { to_table: :tags }, null: true
  end
end
