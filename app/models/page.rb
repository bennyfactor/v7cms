class Page < ActiveRecord::Base
  # Self-referential association for hierarchical pages
  belongs_to :parent, class_name: 'Page', optional: true
  has_many :children, class_name: 'Page', foreign_key: 'parent_id', dependent: :destroy

  # Validations
  validates :title, presence: true
  validates :slug, presence: true, uniqueness: true, format: { with: /\A[a-z0-9-]+\z/, message: 'only allows lowercase letters, numbers, and hyphens' }
  validates :page_type, inclusion: { in: %w[standard landing contact], message: '%{value} is not a valid page type' }
  validates :position, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

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

    result = []
    current = parent
    while current
      result << current
      current = current.parent
    end
    result.reverse
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

  private

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
