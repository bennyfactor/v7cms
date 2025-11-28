# frozen_string_literal: true

require 'swagger/blocks'

class PostSchemas
  include Swagger::Blocks

  swagger_schema :Post do
    key :type, :object
    property :id do
      key :type, :integer
    end
    property :title do
      key :type, :string
    end
    property :slug do
      key :type, :string
    end
    property :content do
      key :type, :string
    end
    property :published do
      key :type, :boolean
    end
    property :comments_enabled do
      key :type, :boolean
    end
    property :comments_allowed do
      key :type, :boolean
      key :description, 'Whether comments can be submitted (considers global and post settings)'
    end
    property :created_at do
      key :type, :string
      key :format, 'date-time'
    end
    property :updated_at do
      key :type, :string
      key :format, 'date-time'
    end
  end

  swagger_schema :PostInput do
    key :type, :object
    key :required, [:title, :content]
    property :title do
      key :type, :string
      key :maxLength, 200
    end
    property :slug do
      key :type, :string
      key :maxLength, 100
      key :description, 'URL-friendly identifier (auto-generated from title if not provided)'
    end
    property :content do
      key :type, :string
    end
    property :published do
      key :type, :boolean
      key :default, false
    end
    property :comments_enabled do
      key :type, :boolean
      key :default, true
    end
  end

  swagger_schema :PostList do
    key :type, :object
    property :posts do
      key :type, :array
      items do
        key :'$ref', :Post
      end
    end
    property :pagination do
      key :'$ref', :Pagination
    end
  end
end
