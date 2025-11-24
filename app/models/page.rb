class Page < ActiveRecord::Base
  # Self-referential association for hierarchical pages
  belongs_to :parent, class_name: 'Page', optional: true
  has_many :children, class_name: 'Page', foreign_key: 'parent_id', dependent: :destroy

  # Validations
  validates :title, presence: true
  validates :slug, presence: true, uniqueness: true, format: { with: /\A[a-z0-9-]+\z/, message: 'only allows lowercase letters, numbers, and hyphens' }
  validates :page_type, inclusion: { in: %w[standard landing contact], message: '%{value} is not a valid page type' }
  validates :position, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validate :prevent_circular_reference

  # Callbacks
  before_validation :generate_slug, if: -> { slug.blank? && title.present? }

  # Static file generation callbacks
  after_commit :generate_static_file, if: :should_generate_static_file?
  after_commit :remove_static_file, if: :should_remove_static_file?
  after_destroy :remove_static_file

  # Scopes
  scope :published, -> { where(published: true) }
  scope :top_level, -> { where(parent_id: nil) }
  scope :ordered, -> { order(:position, :title) }

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
        WHERE id = #{Page.connection.quote(parent_id)}

        UNION ALL

        SELECT p.id, p.parent_id, ancestors_cte.level + 1
        FROM pages p
        INNER JOIN ancestors_cte ON p.id = ancestors_cte.parent_id
      )
      SELECT id FROM ancestors_cte WHERE id != #{Page.connection.quote(id)} ORDER BY level DESC
    SQL

    ancestor_ids = Page.connection.select_values(sql)
    return [] if ancestor_ids.empty?

    # Load all ancestors in one query and maintain hierarchical order
    ancestors_hash = Page.where(id: ancestor_ids).index_by(&:id)
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

  # Returns full slug path including ancestors (e.g., "grandparent/parent/child")
  def full_slug_path
    breadcrumb_trail.map(&:slug).join('/')
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
    published? && !destroyed?
  end

  def should_remove_static_file?
    !destroyed? && saved_change_to_published? && !published?
  end

  def generate_static_file
    PageRenderer.write_static_file(self)
  end

  def remove_static_file
    PageRenderer.delete_static_file(self)
  end
end
