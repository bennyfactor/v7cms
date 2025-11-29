class CreateRedirects < ActiveRecord::Migration[8.1]
  def change
    create_table :redirects do |t|
      t.string :short_path, null: false
      t.string :target_path, null: false
      t.timestamps
    end

    add_index :redirects, :short_path, unique: true
  end
end
