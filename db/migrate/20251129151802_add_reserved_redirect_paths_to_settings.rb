class AddReservedRedirectPathsToSettings < ActiveRecord::Migration[8.1]
  def change
    add_column :settings, :reserved_redirect_paths, :text, default: '/,/admin,/api,/auth,/feed,/posts,/pages'
  end
end
