class Redirect < ActiveRecord::Base
  validates :short_path, presence: true, uniqueness: true
  validates :target_path, presence: true

  before_validation :normalize_paths
  validate :short_path_not_reserved

  after_save :regenerate_htaccess
  after_destroy :regenerate_htaccess

  RESERVED_PATHS = %w[/ /admin /api /auth /feed /posts /pages].freeze

  private

  def normalize_paths
    self.short_path = "/#{short_path.to_s.gsub(/^\/+/, '')}" if short_path.present?
    self.target_path = "/#{target_path.to_s.gsub(/^\/+/, '')}" if target_path.present?
  end

  def short_path_not_reserved
    return unless short_path.present?

    # Get reserved paths from settings, fall back to hardcoded defaults
    reserved_paths = begin
      Setting.instance.reserved_paths_array
    rescue
      []
    end
    reserved_paths = RESERVED_PATHS if reserved_paths.empty?

    if reserved_paths.any? { |r| short_path == r || short_path.start_with?("#{r}/") }
      errors.add(:short_path, "conflicts with reserved path")
    end
  end

  def regenerate_htaccess
    HtaccessGenerator.generate
  end
end
