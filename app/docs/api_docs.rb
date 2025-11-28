# frozen_string_literal: true

require 'swagger/blocks'

# Load all swagger documentation files
require_relative 'swagger_root'
require_relative 'schemas/common'
require_relative 'schemas/post'
require_relative 'schemas/page'
require_relative 'schemas/comment'
require_relative 'schemas/settings'
require_relative 'schemas/theme'
require_relative 'schemas/auth'
require_relative 'paths/posts'
require_relative 'paths/pages'
require_relative 'paths/comments'
require_relative 'paths/settings'
require_relative 'paths/theme'
require_relative 'paths/auth'
require_relative 'paths/feeds'

module ApiDocs
  # All classes that contain swagger definitions
  SWAGGER_CLASSES = [
    SwaggerRoot,
    CommonSchemas,
    PostSchemas,
    PageSchemas,
    CommentSchemas,
    SettingsSchemas,
    ThemeSchemas,
    AuthSchemas,
    PostPaths,
    PagePaths,
    CommentPaths,
    SettingsPaths,
    ThemePaths,
    AuthPaths,
    FeedPaths
  ].freeze

  # Generate the complete OpenAPI specification
  def self.generate_spec
    Swagger::Blocks.build_root_json(SWAGGER_CLASSES)
  end
end
