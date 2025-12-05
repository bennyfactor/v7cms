# frozen_string_literal: true

class AddLayoutPostToSettings < ActiveRecord::Migration[7.0]
  def change
    add_column :settings, :layout_post, :string, default: 'standard'
  end
end
