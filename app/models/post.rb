class Post < ActiveRecord::Base
  validates :title, presence: true
  validates :slug, presence: true, uniqueness: true

  before_validation :generate_slug, on: :create

  # Static file generation callbacks
  after_commit :generate_static_file, if: :should_generate_static_file?
  after_commit :remove_static_file, if: :should_remove_static_file?
  after_destroy :remove_static_file

  scope :published, -> { where(published: true) }
  scope :recent, -> { order(created_at: :desc) }

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
end
