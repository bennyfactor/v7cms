# frozen_string_literal: true

module V7CMS
  class ContentVersion < ActiveRecord::Base
    belongs_to :versionable, polymorphic: true
    belongs_to :created_by, class_name: 'V7CMS::User', optional: true

    VERSION_TYPES = %w[auto workflow manual].freeze
    WORKFLOW_STATES = %w[published unpublished].freeze

    validates :version_number, presence: true, numericality: { greater_than: 0 }
    validates :version_type, inclusion: { in: VERSION_TYPES }
    validates :workflow_state, inclusion: { in: WORKFLOW_STATES }, allow_nil: true
    validates :title, presence: true

    scope :for_record, ->(record) {
      where(versionable_type: record.class.name.demodulize, versionable_id: record.id)
    }
    scope :permanent, -> { where(expires_at: nil) }
    scope :temporary, -> { where.not(expires_at: nil) }
    scope :expired, -> { where('expires_at < ?', Time.current) }
    scope :by_version, -> { order(version_number: :desc) }

    def permanent?
      expires_at.nil?
    end

    def temporary?
      !permanent?
    end

    def mark_permanent!
      update!(version_type: 'manual', expires_at: nil)
    end

    def metadata_hash
      return {} if metadata.blank?
      JSON.parse(metadata)
    rescue JSON::ParserError
      {}
    end

    def restore_to_parent!
      parent = versionable
      parent.title = title
      parent.content = content

      metadata_hash.each do |key, value|
        parent.send("#{key}=", value) if parent.respond_to?("#{key}=")
      end

      parent.save!
    end

    def self.cleanup_expired!
      expired.delete_all
    end
  end
end
