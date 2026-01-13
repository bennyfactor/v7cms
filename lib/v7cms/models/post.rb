module V7CMS
  class Post < ActiveRecord::Base
    include V7CMS::Versionable

    STATUSES = %w[draft ready published].freeze

    has_many :comments, class_name: 'V7CMS::Comment', dependent: :destroy
    belongs_to :published_version, class_name: 'V7CMS::ContentVersion', optional: true

    validates :title, presence: true
    validates :slug, presence: true, uniqueness: true
    validates :status, inclusion: { in: STATUSES }
    validates :comments_enabled, inclusion: { in: [true, false] }

    before_validation :generate_slug, on: :create
    before_save :flip_to_draft_on_content_change, if: :should_flip_to_draft?

    # Static file generation callbacks
    after_commit :generate_static_file, if: :should_generate_static_file?
    after_commit :remove_static_file, if: :should_remove_static_file?
    after_destroy :remove_static_file

    # Feed regeneration callback
    after_commit :regenerate_feeds

    scope :published, -> { where.not(published_version_id: nil) }
    scope :recent, -> { order(created_at: :desc) }

    def comments_allowed?
      comments_enabled && V7CMS::Setting.instance.allow_comments
    end

    def has_unpublished_changes?
      return false unless published_version_id.present?
      title != published_version.title || content != published_version.content
    end

    def publish!
      version = create_workflow_version!(workflow_state: 'published')
      update!(status: 'published', published_version_id: version.id)
    end

    def unpublish!
      create_workflow_version!(workflow_state: 'unpublished')
      update!(status: 'draft', published_version_id: nil)
    end

    # Backward compatibility
    def published?
      published_version_id.present?
    end

    private

    def generate_slug
      return if slug.present? || title.blank?

      self.slug = title.downcase
        .gsub(/[^a-z0-9\s-]/, '') # Remove non-alphanumeric chars except spaces and hyphens
        .gsub(/\s+/, '-')          # Replace spaces with hyphens
        .gsub(/-+/, '-')           # Replace multiple hyphens with single hyphen
        .strip                     # Remove leading/trailing whitespace
        .gsub(/^-|-$/, '')        # Remove leading/trailing hyphens
    end

    def should_generate_static_file?
      published_version_id.present? && !destroyed?
    end

    def should_remove_static_file?
      !destroyed? && saved_change_to_published_version_id? && published_version_id.nil?
    end

    def generate_static_file
      PostRenderer.write_static_file(self)
    end

    def remove_static_file
      PostRenderer.delete_static_file(self)
    end

    def regenerate_feeds
      FeedGenerator.write_feeds
    end

    def version_metadata
      {
        slug: slug,
        comments_enabled: comments_enabled
      }
    end

    def should_flip_to_draft?
      !new_record? && status == 'published' && (will_save_change_to_title? || will_save_change_to_content?)
    end

    def flip_to_draft_on_content_change
      self.status = 'draft'
    end
  end
end
