# frozen_string_literal: true

module V7CMS
  # Resolves file paths with user-first lookup
  # User's project files take priority over gem's bundled files
  class FileResolver
    attr_reader :project_root, :gem_root

    def initialize(project_root:, gem_root:)
      @project_root = project_root
      @gem_root = gem_root
    end

    # Returns first existing path, user's project takes priority
    # @param relative_path [String] Path relative to root (e.g., 'views/layout.erb')
    # @return [String, nil] Absolute path to file, or nil if not found
    def resolve(relative_path)
      user_path = File.join(@project_root, relative_path)
      return user_path if File.exist?(user_path)

      gem_path = File.join(@gem_root, 'lib', 'v7cms', relative_path)
      return gem_path if File.exist?(gem_path)

      nil
    end

    # Returns all existing paths (for merging, like view directories)
    # User paths come first in the array for priority
    # @param relative_path [String] Path relative to root
    # @return [Array<String>] Array of absolute paths that exist
    def resolve_all(relative_path)
      paths = []

      user_path = File.join(@project_root, relative_path)
      paths << user_path if File.exist?(user_path)

      gem_path = File.join(@gem_root, 'lib', 'v7cms', relative_path)
      paths << gem_path if File.exist?(gem_path)

      paths
    end

    # Check if a file exists in either location
    # @param relative_path [String] Path relative to root
    # @return [Boolean]
    def exist?(relative_path)
      !resolve(relative_path).nil?
    end

    # Read file content, preferring user's version
    # @param relative_path [String] Path relative to root
    # @return [String, nil] File contents or nil if not found
    def read(relative_path)
      path = resolve(relative_path)
      path ? File.read(path) : nil
    end
  end
end
