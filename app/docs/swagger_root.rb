# frozen_string_literal: true

require 'swagger/blocks'

class SwaggerRoot
  include Swagger::Blocks

  swagger_root do
    key :openapi, '3.0.0'
    info do
      key :title, 'v7cms API'
      key :version, '1.0.0'
      key :description, 'RESTful API for v7cms content management system'
      contact do
        key :name, 'API Support'
      end
    end

    server do
      key :url, 'https://dev.iaatb.net'
      key :description, 'Production server'
    end
    server do
      key :url, 'http://localhost:9292'
      key :description, 'Development server'
    end

    key :tags, [
      { name: 'Posts', description: 'Blog post management' },
      { name: 'Pages', description: 'Static page management' },
      { name: 'Comments', description: 'Comment system' },
      { name: 'Settings', description: 'Site settings' },
      { name: 'Theme', description: 'Theme customization' },
      { name: 'Auth', description: 'Authentication' },
      { name: 'Feeds', description: 'RSS and Atom feeds' }
    ]
  end
end
