# frozen_string_literal: true

module V7CMS
  class MenuItem < ActiveRecord::Base
    belongs_to :menu
    belongs_to :parent, class_name: 'V7CMS::MenuItem', optional: true
    has_many :children, -> { order(:position) }, class_name: 'V7CMS::MenuItem',
                                                 foreign_key: :parent_id, dependent: :destroy

    belongs_to :linkable, polymorphic: true, optional: true

    thread_mattr_accessor :skip_regeneration

    def self.suppress_regeneration?
      skip_regeneration == true
    end

    def self.suppress_regeneration
      self.skip_regeneration = true
      yield
    ensure
      self.skip_regeneration = false
    end

    LINK_TYPES = %w[page post custom].freeze
    TARGETS = %w[_blank _self _parent _top].freeze
    LINKABLE_TYPES = %w[V7CMS::Page V7CMS::Post].freeze

    validates :label, presence: true
    validates :link_type, inclusion: { in: LINK_TYPES }
    validates :url, presence: true, if: -> { link_type == 'custom' }
    validates :linkable, presence: true, if: -> { link_type.in?(%w[page post]) }
    validates :linkable_type, inclusion: { in: LINKABLE_TYPES }, allow_blank: true
    validates :target, inclusion: { in: TARGETS }, allow_blank: true
    validate :prevent_circular_reference
    validate :enforce_max_depth
    validate :safe_url
    validate :validate_same_menu_parent
    validate :valid_css_classes

    before_validation :normalize_css_class
    after_commit :trigger_static_regeneration, unless: -> { self.class.suppress_regeneration? }

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

      return unless parent_id == id

      errors.add(:parent_id, 'cannot be self')
    end

    def enforce_max_depth
      return if parent_id.nil?
      return unless parent

      return unless parent.parent_id.present?

      errors.add(:parent_id, 'maximum nesting depth is 2 levels')
    end

    def safe_url
      return if url.blank?
      if url.match?(/\%2f/i)
        errors.add(:url, 'must not contain encoded slashes')
        return
      end
      return if url.start_with?('#')
      return if url.match?(%r{\A/[^/]}) || url == '/'
      return if url.match?(%r{\Ahttps?://})
      return if url.start_with?('mailto:')

      errors.add(:url, 'must be a relative path or use http(s)/mailto protocol')
    end

    def validate_same_menu_parent
      return if parent_id.blank? || parent.blank?

      return if parent.menu_id == menu_id

      errors.add(:parent_id, 'must belong to the same menu')
    end

    def normalize_css_class
      return if css_class.blank?
      self.css_class = css_class.split(/\s+/).map { |token| token.delete_prefix('.') }.join(' ')
    end

    def valid_css_classes
      return if css_class.blank?
      css_class.split(/\s+/).each do |token|
        next if token.match?(/\A[a-zA-Z_-][a-zA-Z0-9_-]*\z/)
        errors.add(:css_class, "contains invalid class name '#{token}'")
        return
      end
    end

    def trigger_static_regeneration
      return if destroyed_by_association

      menu&.regenerate_all_static_files
    end
  end
end
