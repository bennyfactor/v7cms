module V7CMS
  class Redirect < ActiveRecord::Base
    validates :short_path, presence: true
    validates :target_path, presence: true
    validate :short_path_unique_across_trailing_slash_forms

    before_validation :normalize_paths
    validate :short_path_not_reserved

    after_save :regenerate_htaccess
    after_destroy :regenerate_htaccess

    RESERVED_PATHS = %w[/ /admin /api /auth /feed /posts /pages].freeze

    private

    def normalize_paths
      # One canonical form: leading slash, no trailing slash ("/foo" and
      # "/foo/" are the same redirect and generate the same Apache rule).
      self.short_path = "/#{short_path.to_s.gsub(/^\/+/, '').sub(%r{/+\z}, '')}" if short_path.present?
      self.target_path = "/#{target_path.to_s.gsub(/^\/+/, '')}" if target_path.present?
    end

    # Rows saved before trailing slashes were normalized may still be stored
    # as "/foo/"; treat them as the same redirect as "/foo".
    def short_path_unique_across_trailing_slash_forms
      return if short_path.blank?

      scope = self.class.where(short_path: [short_path, "#{short_path}/"])
      scope = scope.where.not(id: id) if persisted?
      errors.add(:short_path, 'has already been taken') if scope.exists?
    end

    def short_path_not_reserved
      return unless short_path.present?

      # Get reserved paths from settings, fall back to hardcoded defaults
      reserved_paths = begin
        V7CMS::Setting.instance.reserved_paths_array
      rescue
        []
      end
      reserved_paths = RESERVED_PATHS if reserved_paths.empty?

      errors.add(:short_path, "conflicts with reserved path") if reserved_paths.any? { |r| short_path == r || short_path.start_with?("#{r}/") }
    end

    def regenerate_htaccess
      HtaccessGenerator.generate
    end
  end
end
