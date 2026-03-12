module V7CMS
  class Tag < ActiveRecord::Base
    has_many :post_tags, class_name: 'V7CMS::PostTag', dependent: :destroy
    has_many :posts, through: :post_tags, class_name: 'V7CMS::Post'

    validates :name, presence: true,
                     uniqueness: { case_sensitive: false },
                     length: { maximum: 100 }
    validates :slug, presence: true, uniqueness: true

    before_validation :generate_slug, on: :create

    scope :ordered, -> { order(:name) }

    def posts_count
      posts.count
    end

    private

    def generate_slug
      return if slug.present? || name.blank?

      self.slug = name.downcase
                      .gsub(/[^a-z0-9\s-]/, '')
                      .gsub(/\s+/, '-').squeeze('-')
                      .strip
                      .gsub(/^-|-$/, '')
    end
  end
end
