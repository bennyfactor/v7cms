# frozen_string_literal: true

module V7CMS
  class MenuItem < ActiveRecord::Base
    belongs_to :menu
    belongs_to :parent, class_name: 'V7CMS::MenuItem', optional: true
    has_many :children, -> { order(:position) }, class_name: 'V7CMS::MenuItem',
             foreign_key: :parent_id, dependent: :destroy

    belongs_to :linkable, polymorphic: true, optional: true

    LINK_TYPES = %w[page post custom].freeze
    TARGETS = %w[_blank _self _parent _top].freeze

    validates :label, presence: true
    validates :link_type, inclusion: { in: LINK_TYPES }
    validates :url, presence: true, if: -> { link_type == 'custom' }
    validates :linkable, presence: true, if: -> { link_type.in?(%w[page post]) }
    validates :target, inclusion: { in: TARGETS }, allow_blank: true
    validate :prevent_circular_reference
    validate :enforce_max_depth
    validate :safe_url

    after_commit :trigger_static_regeneration

    def href
      case link_type
      when 'page'
        linkable ? "/#{linkable.full_slug_path}" : '#'
      when 'post'
        linkable ? "/posts/#{linkable.slug}" : '#'
      when 'custom'
        url
      else
        '#'
      end
    end

    def to_nested_hash
      {
        id: id,
        label: label,
        href: href,
        target: target,
        children: children.includes(:linkable).map(&:to_nested_hash)
      }
    end

    private

    def prevent_circular_reference
      return if parent_id.nil?

      if parent_id == id
        errors.add(:parent_id, 'cannot be self')
      end
    end

    def enforce_max_depth
      return if parent_id.nil?
      return unless parent

      if parent.parent_id.present?
        errors.add(:parent_id, 'maximum nesting depth is 2 levels')
      end
    end

    def safe_url
      return if url.blank?

      if url.match?(/\Ajavascript:/i)
        errors.add(:url, 'cannot use javascript: protocol')
      end
    end

    def trigger_static_regeneration
      menu&.regenerate_all_static_files
    end
  end
end
