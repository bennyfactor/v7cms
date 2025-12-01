module V7CMS
  class Post < ActiveRecord::Base
    has_many :comments, class_name: 'V7CMS::Comment', dependent: :destroy

    validates :title, presence: true
    validates :slug, presence: true, uniqueness: true
    validates :comments_enabled, inclusion: { in: [true, false] }

    before_validation :generate_slug, on: :create

    # Static file generation callbacks
    after_commit :generate_static_file, if: :should_generate_static_file?
    after_commit :remove_static_file, if: :should_remove_static_file?
    after_destroy :remove_static_file

    # Feed regeneration callback
    after_commit :regenerate_feeds

    scope :published, -> { where(published: true) }
    scope :recent, -> { order(created_at: :desc) }

    def comments_allowed?
      comments_enabled && V7CMS::Setting.instance.allow_comments
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
      published? && !destroyed?
    end

    def should_remove_static_file?
      !destroyed? && saved_change_to_published? && !published?
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
  end
end
