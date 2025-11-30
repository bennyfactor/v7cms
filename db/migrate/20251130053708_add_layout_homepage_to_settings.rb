class AddLayoutHomepageToSettings < ActiveRecord::Migration[8.1]
  def change
    add_column :settings, :layout_homepage, :string, default: 'blog_list'
  end
end
