# frozen_string_literal: true

class CreateFormSubmissions < ActiveRecord::Migration[8.1]
  def change
    create_table :form_submissions do |t|
      t.references :form, null: false, foreign_key: true
      t.text :data, null: false
      t.string :ip_address
      t.float :recaptcha_score
      t.boolean :spam, null: false, default: false
      t.timestamps
    end

    add_index :form_submissions, %i[form_id spam]
    add_index :form_submissions, :created_at
  end
end
