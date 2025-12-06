class AddHeroImageUrlToPages < ActiveRecord::Migration[7.0]
  def change
    add_column :pages, :hero_image_url, :string, limit: 2048
  end
end
