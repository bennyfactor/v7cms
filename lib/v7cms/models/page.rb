module V7CMS
  class Page < ActiveRecord::Base
    include V7CMS::Versionable

    STATUSES = %w[draft ready published].freeze

    # Self-referential association for hierarchical pages
    belongs_to :parent, class_name: 'V7CMS::Page', optional: true
    has_many :children, class_name: 'V7CMS::Page', foreign_key: 'parent_id', dependent: :destroy
    belongs_to :published_version, class_name: 'V7CMS::ContentVersion', optional: true
    belongs_to :content_filter_tag, class_name: 'V7CMS::Tag', optional: true

    # Static page types + all homepage layout types
    STATIC_PAGE_TYPES = %w[standard contact].freeze
    LAYOUT_PAGE_TYPES = %w[blog_list blog_grid hero_grid magazine minimal portfolio landing].freeze
    VALID_PAGE_TYPES = (STATIC_PAGE_TYPES + LAYOUT_PAGE_TYPES).freeze

    VALID_CONTENT_SOURCES = %w[children posts].freeze

    # Validations
    validates :title, presence: true
    validates :slug, presence: true, uniqueness: true, format: { with: /\A[a-z0-9-]+\z/, message: 'only allows lowercase letters, numbers, and hyphens' }
    validates :status, inclusion: { in: STATUSES }
    validates :page_type, inclusion: { in: VALID_PAGE_TYPES, message: '%{value} is not a valid page type' }
    validates :content_source, inclusion: { in: VALID_CONTENT_SOURCES, message: '%{value} is not a valid content source' }
    validates :items_limit, numericality: { only_integer: true, greater_than: 0, less_than_or_equal_to: 100 }
    validates :position, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
    validate :prevent_circular_reference
    validates :hero_image_url, format: {
      with: URI::DEFAULT_PARSER.make_regexp(%w[http https]),
      message: 'must be a valid URL'
    }, allow_blank: true

    # Callbacks
    before_validation :generate_slug, if: -> { slug.blank? && title.present? }
    before_save :flip_to_draft_on_content_change, if: :should_flip_to_draft?
    before_save :compute_full_slug_path
    after_save :cascade_full_slug_path, if: -> { saved_change_to_slug? || saved_change_to_parent_id? }

    # Static file generation callbacks
    after_commit :generate_static_file, if: :should_generate_static_file?
    after_commit :remove_static_file, if: :should_remove_static_file?
    after_destroy :remove_static_file

    # Scopes
    scope :published, -> { where.not(published_version_id: nil) }
    scope :top_level, -> { where(parent_id: nil) }
    scope :ordered, -> { order(:position, :title) }

    # Check if this page uses a layout template (vs static page.erb)
    def uses_layout_template?
      LAYOUT_PAGE_TYPES.include?(page_type)
    end

    # Get items to display based on content_source
    def items_for_display
      case content_source
      when 'posts'
        scope = V7CMS::Post.published.order(created_at: :desc)
        scope = scope.joins(:tags).where(tags: { id: content_filter_tag_id }).distinct if content_filter_tag_id.present?
        scope.limit(items_limit)
      else # 'children' is default
        children.published.ordered.limit(items_limit)
      end
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

    # Generate URL-friendly slug from title
    def generate_slug
      self.slug = title.parameterize
    end

    # Get all ancestors (parent, grandparent, etc.)
    def ancestors
      return [] unless parent_id

      # Use recursive SQL query (Common Table Expression) for single-query performance
      sql = <<-SQL
        WITH RECURSIVE ancestors_cte(id, parent_id, level) AS (
          SELECT id, parent_id, 1 as level
          FROM pages
          WHERE id = #{V7CMS::Page.connection.quote(parent_id)}

          UNION ALL

          SELECT p.id, p.parent_id, ancestors_cte.level + 1
          FROM pages p
          INNER JOIN ancestors_cte ON p.id = ancestors_cte.parent_id
        )
        SELECT id FROM ancestors_cte WHERE id != #{V7CMS::Page.connection.quote(id)} ORDER BY level DESC
      SQL

      ancestor_ids = V7CMS::Page.connection.select_values(sql)
      return [] if ancestor_ids.empty?

      # Load all ancestors in one query and maintain hierarchical order
      ancestors_hash = V7CMS::Page.where(id: ancestor_ids).index_by(&:id)
      ancestor_ids.map { |aid| ancestors_hash[aid] }.compact
    end

    # Get all descendants (children, grandchildren, etc.)
    def descendants
      result = children.to_a
      children.each do |child|
        result.concat(child.descendants)
      end
      result
    end

    # Get breadcrumb trail as array of pages from root to self
    def breadcrumb_trail
      ancestors + [self]
    end

    # Check if this page has children
    def has_children?
      children.any?
    end

    # Get depth level (0 for top-level pages)
    def depth
      ancestors.count
    end

    def self.backfill_full_slug_paths!
      V7CMS::Page.where(parent_id: nil).find_each do |page|
        path = page.breadcrumb_trail.map(&:slug).join('/')
        page.update_columns(full_slug_path: path)
        backfill_descendants!(page)
      end
    end

    def self.backfill_descendants!(page)
      page.children.find_each do |child|
        path = child.breadcrumb_trail.map(&:slug).join('/')
        child.update_columns(full_slug_path: path)
        backfill_descendants!(child)
      end
    end

    private

    def prevent_circular_reference
      return if parent_id.nil?

      # Check if parent_id is self
      if parent_id == id
        errors.add(:parent_id, 'cannot be a circular reference')
        return
      end

      # Check if parent_id is one of our descendants
      descendant_ids = descendants.map(&:id)
      if descendant_ids.include?(parent_id)
        errors.add(:parent_id, 'cannot be a circular reference')
      end
    end

    def should_generate_static_file?
      published_version_id.present? && !destroyed?
    end

    def should_remove_static_file?
      !destroyed? && saved_change_to_published_version_id? && published_version_id.nil?
    end

    def generate_static_file
      PageRenderer.write_static_file(self)
    end

    def remove_static_file
      PageRenderer.delete_static_file(self)
    end

    def version_metadata
      {
        slug: slug,
        page_type: page_type,
        content_source: content_source,
        items_limit: items_limit,
        position: position,
        parent_id: parent_id,
        hero_image_url: hero_image_url,
        content_filter_tag_id: content_filter_tag_id
      }
    end

    def should_flip_to_draft?
      !new_record? && status == 'published' && (will_save_change_to_title? || will_save_change_to_content?)
    end

    def flip_to_draft_on_content_change
      self.status = 'draft'
    end

    def compute_full_slug_path
      self.full_slug_path = if parent_id.present?
                              parent_page = self.class.find_by(id: parent_id)
                              parent_page ? "#{parent_page.full_slug_path}/#{slug}" : slug
                            else
                              slug
                            end
    end

    def cascade_full_slug_path(parent_path = full_slug_path)
      self.class.where(parent_id: id).find_each do |child|
        new_path = "#{parent_path}/#{child.slug}"
        child.update_columns(full_slug_path: new_path)
        child.send(:cascade_full_slug_path, new_path)
      end
    end
  end
end
