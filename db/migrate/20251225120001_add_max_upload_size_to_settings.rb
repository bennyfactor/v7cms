# frozen_string_literal: true

class AddMaxUploadSizeToSettings < ActiveRecord::Migration[7.0]
  def change
    add_column :settings, :max_upload_size, :integer, default: 10_485_760
  end
end
