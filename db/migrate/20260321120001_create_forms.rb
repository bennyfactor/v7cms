# frozen_string_literal: true

class CreateForms < ActiveRecord::Migration[8.1]
  def change
    create_table :forms do |t|
      t.string :name, null: false
      t.string :slug, null: false
      t.text :description
      t.string :submit_button_text, null: false, default: 'Submit'
      t.text :success_message, null: false, default: 'Thank you for your submission.'
      t.string :notification_email
      t.boolean :store_submissions, null: false, default: true
      t.boolean :send_notifications, null: false, default: false
      t.boolean :require_recaptcha, null: false, default: true
      t.float :recaptcha_threshold, null: false, default: 0.5
      t.string :spam_behavior, null: false, default: 'store'
      t.boolean :published, null: false, default: false
      t.timestamps
    end

    add_index :forms, :slug, unique: true
    add_index :forms, :published
  end
end
