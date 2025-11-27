class CreateComments < ActiveRecord::Migration[8.1]
  def change
    create_table :comments do |t|
      t.references :post, null: false, index: true, foreign_key: true
      t.string :author_name, null: false
      t.string :author_email, null: false
      t.string :author_url
      t.text :content, null: false
      t.string :ip_address
      t.float :recaptcha_score
      t.boolean :approved, default: false, null: false
      t.boolean :spam, default: false, null: false
      t.timestamps
    end

    add_index :comments, :approved
    add_index :comments, :spam
    add_index :comments, :created_at
  end
end
