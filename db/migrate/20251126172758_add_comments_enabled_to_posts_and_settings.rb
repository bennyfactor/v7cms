class AddCommentsEnabledToPostsAndSettings < ActiveRecord::Migration[8.1]
  def change
    add_column :posts, :comments_enabled, :boolean, default: true, null: false
    add_column :settings, :allow_comments, :boolean, default: true, null: false

    add_index :posts, :comments_enabled
  end
end
