# frozen_string_literal: true

class CreateFormFields < ActiveRecord::Migration[8.1]
  def change
    create_table :form_fields do |t|
      t.references :form, null: false, foreign_key: true
      t.string :field_type, null: false
      t.string :name, null: false
      t.string :label
      t.string :placeholder
      t.string :help_text
      t.boolean :required, null: false, default: false
      t.text :options
      t.text :validation_rules
      t.integer :position, null: false, default: 0
      t.timestamps
    end

    add_index :form_fields, %i[form_id name], unique: true
    add_index :form_fields, %i[form_id position]
  end
end
