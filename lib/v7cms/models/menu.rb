# frozen_string_literal: true

module V7CMS
  class Menu < ActiveRecord::Base
    has_many :menu_items, -> { order(:position) }, dependent: :destroy
    has_many :root_items, -> { where(parent_id: nil).order(:position) },
             class_name: 'V7CMS::MenuItem'

    LOCATIONS = %w[header footer sidebar].freeze

    validates :name, presence: true
    validates :slug, presence: true, uniqueness: true,
                     format: { with: /\A[a-z0-9_-]+\z/,
                               message: 'only allows lowercase letters, numbers, hyphens, and underscores' }
    validates :location, inclusion: { in: LOCATIONS }, allow_blank: true
    validate :unique_location

    before_validation :generate_slug, if: -> { slug.blank? && name.present? }

    after_commit :regenerate_all_static_files

    def self.at_location(location)
      find_by(location: location)
    end

    def self.by_slug(slug)
      find_by(slug: slug)
    end

    def nested_items
      root_items.includes(children: :linkable, linkable: []).map(&:to_nested_hash)
    end

    def regenerate_all_static_files
      require_relative '../services/post_renderer'
      require_relative '../services/page_renderer'

      V7CMS::Post.published.find_each { |post| PostRenderer.write_static_file(post) }
      V7CMS::Page.published.find_each { |page| PageRenderer.write_static_file(page) }
    end

    private

    def generate_slug
      self.slug = name.parameterize
    end

    def unique_location
      return if location.blank?

      existing = self.class.where(location: location)
      existing = existing.where.not(id: id) if persisted?
      errors.add(:location, 'is already assigned to another menu') if existing.exists?
    end
  end
end
