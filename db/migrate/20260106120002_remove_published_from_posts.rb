class RemovePublishedFromPosts < ActiveRecord::Migration[7.0]
  def change
    remove_column :posts, :published, :boolean, default: false
  end
end
