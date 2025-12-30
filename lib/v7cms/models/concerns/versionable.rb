# frozen_string_literal: true

module V7CMS
  module Versionable
    extend ActiveSupport::Concern

    included do
      has_many :content_versions,
               -> { order(version_number: :desc) },
               as: :versionable,
               class_name: 'V7CMS::ContentVersion',
               dependent: :destroy

      after_save :create_auto_version_on_save, if: :should_create_auto_version?
    end

    def create_auto_version!(created_by: nil)
      create_version!(
        version_type: 'auto',
        created_by: created_by,
        expires_at: 24.hours.from_now
      )
    end

    def create_workflow_version!(workflow_state:, created_by: nil)
      create_version!(
        version_type: 'workflow',
        workflow_state: workflow_state,
        created_by: created_by,
        expires_at: nil
      )
    end

    def create_version!(version_type:, created_by: nil, expires_at: nil, workflow_state: nil)
      next_version = (content_versions.maximum(:version_number) || 0) + 1

      content_versions.create!(
        version_number: next_version,
        version_type: version_type,
        workflow_state: workflow_state,
        title: title,
        content: content,
        metadata: version_metadata.to_json,
        created_by: created_by,
        expires_at: expires_at
      )
    end

    def latest_version
      content_versions.reload.first
    end

    def version_at(number)
      content_versions.find_by(version_number: number)
    end

    def restore_version!(number)
      version = version_at(number)
      raise ActiveRecord::RecordNotFound, "Version #{number} not found" unless version
      version.restore_to_parent!
    end

    private

    def create_auto_version_on_save
      create_auto_version!
    end

    def should_create_auto_version?
      saved_change_to_title? || saved_change_to_content?
    end

    def version_metadata
      { slug: slug }
    end
  end
end
