class RemovePublishedFromPages < ActiveRecord::Migration[7.0]
  def change
    remove_column :pages, :published, :boolean, default: false
  end
end
