# frozen_string_literal: true

# Load all V7CMS model files
# Models are namespaced under V7CMS (e.g., V7CMS::User, V7CMS::Post)
require_relative 'models/concerns/versionable'
require_relative 'models/user'
require_relative 'models/post'
require_relative 'models/tag'
require_relative 'models/post_tag'
require_relative 'models/page'
require_relative 'models/comment'
require_relative 'models/setting'
require_relative 'models/theme'
require_relative 'models/redirect'
require_relative 'models/asset'
require_relative 'models/content_version'
require_relative 'models/menu'
require_relative 'models/menu_item'
require_relative 'models/form'
require_relative 'models/form_field'
require_relative 'models/form_submission'
