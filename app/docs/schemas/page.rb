# frozen_string_literal: true

require 'swagger/blocks'

class PageSchemas
  include Swagger::Blocks

  swagger_schema :Page do
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
    property :parent_id do
      key :type, :integer
      key :nullable, true
    end
    property :page_type do
      key :type, :string
      key :enum, ['standard', 'landing', 'contact']
    end
    property :position do
      key :type, :integer
    end
    property :full_path do
      key :type, :string
      key :description, 'Full hierarchical URL path'
    end
    property :breadcrumbs do
      key :type, :array
      items do
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
      end
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

  swagger_schema :PageInput do
    key :type, :object
    key :required, [:title, :content]
    property :title do
      key :type, :string
      key :maxLength, 200
    end
    property :slug do
      key :type, :string
      key :maxLength, 100
    end
    property :content do
      key :type, :string
    end
    property :published do
      key :type, :boolean
      key :default, false
    end
    property :parent_id do
      key :type, :integer
      key :nullable, true
    end
    property :page_type do
      key :type, :string
      key :enum, ['standard', 'landing', 'contact']
      key :default, 'standard'
    end
    property :position do
      key :type, :integer
      key :default, 0
    end
  end

  swagger_schema :PageList do
    key :type, :object
    property :pages do
      key :type, :array
      items do
        key :'$ref', :Page
      end
    end
    property :pagination do
      key :'$ref', :Pagination
    end
  end
end
