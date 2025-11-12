class Post < ActiveRecord::Base
  validates :title, presence: true
  validates :slug, presence: true, uniqueness: true

  before_validation :generate_slug, on: :create

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
end
