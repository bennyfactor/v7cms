# frozen_string_literal: true

module V7CMS
  class Asset < ActiveRecord::Base
    belongs_to :uploaded_by, class_name: 'V7CMS::User', optional: true

    validates :filename, presence: true
    validates :original_filename, presence: true
    validates :content_type, presence: true
    validates :file_size, presence: true, numericality: { greater_than: 0 }
    validates :storage_key, presence: true, uniqueness: true

    ALLOWED_CONTENT_TYPES = %w[
      image/jpeg image/png image/gif image/webp image/svg+xml
      application/pdf
      application/msword application/vnd.openxmlformats-officedocument.wordprocessingml.document
      application/vnd.ms-excel application/vnd.openxmlformats-officedocument.spreadsheetml.sheet
      audio/mpeg
      video/mp4
      application/zip
    ].freeze

    validates :content_type, inclusion: {
      in: ALLOWED_CONTENT_TYPES,
      message: 'is not an allowed file type'
    }

    scope :images, -> { where("content_type LIKE 'image/%'") }
    scope :documents, -> { where(content_type: %w[application/pdf application/msword application/vnd.openxmlformats-officedocument.wordprocessingml.document application/vnd.ms-excel application/vnd.openxmlformats-officedocument.spreadsheetml.sheet]) }
    scope :audio, -> { where("content_type LIKE 'audio/%'") }
    scope :video, -> { where("content_type LIKE 'video/%'") }
    scope :archives, -> { where(content_type: 'application/zip') }
    scope :recent, -> { order(created_at: :desc) }

    def image?
      content_type&.start_with?('image/')
    end

    def url
      "/upload/#{storage_key}"
    end

    def file_type_category
      case content_type
      when /\Aimage\//
        :image
      when /\Aaudio\//
        :audio
      when /\Avideo\//
        :video
      when 'application/zip'
        :archive
      when 'application/pdf', /word/, /excel/, /spreadsheet/
        :document
      else
        :other
      end
    end

    def self.storage_adapter
      @storage_adapter ||= V7CMS::Storage::LocalAdapter.new
    end
  end
end
