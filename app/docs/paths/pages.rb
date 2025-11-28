# frozen_string_literal: true

require 'swagger/blocks'

class PagePaths
  include Swagger::Blocks

  swagger_path '/api/pages' do
    operation :get do
      key :summary, 'List pages'
      key :description, 'Returns a paginated list of pages with hierarchical information'
      key :operationId, 'listPages'
      key :tags, ['Pages']

      parameter do
        key :name, :include_drafts
        key :in, :query
        key :description, 'Include unpublished pages (requires authentication)'
        key :required, false
        schema do
          key :type, :boolean
        end
      end
      parameter do
        key :name, :parent_id
        key :in, :query
        key :description, 'Filter by parent page ID (use "null" for top-level pages)'
        key :required, false
        schema do
          key :type, :string
        end
      end
      parameter do
        key :name, :limit
        key :in, :query
        key :description, 'Number of pages to return (default: 20, max: 100)'
        key :required, false
        schema do
          key :type, :integer
          key :default, 20
          key :maximum, 100
        end
      end
      parameter do
        key :name, :offset
        key :in, :query
        key :description, 'Number of pages to skip'
        key :required, false
        schema do
          key :type, :integer
          key :default, 0
        end
      end

      response 200 do
        key :description, 'List of pages with pagination'
        content 'application/json' do
          schema do
            key :'$ref', :PageList
          end
        end
      end
    end

    operation :post do
      key :summary, 'Create page'
      key :description, 'Create a new page. Requires authentication.'
      key :operationId, 'createPage'
      key :tags, ['Pages']

      request_body do
        key :required, true
        content 'application/json' do
          schema do
            key :'$ref', :PageInput
          end
        end
      end

      response 201 do
        key :description, 'Page created successfully'
        content 'application/json' do
          schema do
            key :'$ref', :Page
          end
        end
      end
      response 401 do
        key :description, 'Unauthorized'
        content 'application/json' do
          schema do
            key :'$ref', :Error
          end
        end
      end
      response 422 do
        key :description, 'Validation error'
        content 'application/json' do
          schema do
            key :'$ref', :Error
          end
        end
      end
    end
  end

  swagger_path '/api/pages/{id}' do
    operation :get do
      key :summary, 'Get page'
      key :description, 'Get a single page by ID or slug'
      key :operationId, 'getPage'
      key :tags, ['Pages']

      parameter do
        key :name, :id
        key :in, :path
        key :description, 'Page ID or slug'
        key :required, true
        schema do
          key :type, :string
        end
      end

      response 200 do
        key :description, 'Page details with breadcrumbs'
        content 'application/json' do
          schema do
            key :'$ref', :Page
          end
        end
      end
      response 404 do
        key :description, 'Page not found'
        content 'application/json' do
          schema do
            key :'$ref', :Error
          end
        end
      end
    end

    operation :put do
      key :summary, 'Update page'
      key :description, 'Update an existing page. Requires authentication.'
      key :operationId, 'updatePage'
      key :tags, ['Pages']

      parameter do
        key :name, :id
        key :in, :path
        key :description, 'Page ID'
        key :required, true
        schema do
          key :type, :integer
        end
      end

      request_body do
        key :required, true
        content 'application/json' do
          schema do
            key :'$ref', :PageInput
          end
        end
      end

      response 200 do
        key :description, 'Page updated successfully'
        content 'application/json' do
          schema do
            key :'$ref', :Page
          end
        end
      end
      response 401 do
        key :description, 'Unauthorized'
        content 'application/json' do
          schema do
            key :'$ref', :Error
          end
        end
      end
      response 404 do
        key :description, 'Page not found'
        content 'application/json' do
          schema do
            key :'$ref', :Error
          end
        end
      end
      response 422 do
        key :description, 'Validation error'
        content 'application/json' do
          schema do
            key :'$ref', :Error
          end
        end
      end
    end

    operation :delete do
      key :summary, 'Delete page'
      key :description, 'Delete a page and all its children. Requires authentication.'
      key :operationId, 'deletePage'
      key :tags, ['Pages']

      parameter do
        key :name, :id
        key :in, :path
        key :description, 'Page ID'
        key :required, true
        schema do
          key :type, :integer
        end
      end

      response 200 do
        key :description, 'Page deleted successfully'
        content 'application/json' do
          schema do
            key :'$ref', :Success
          end
        end
      end
      response 401 do
        key :description, 'Unauthorized'
        content 'application/json' do
          schema do
            key :'$ref', :Error
          end
        end
      end
      response 404 do
        key :description, 'Page not found'
        content 'application/json' do
          schema do
            key :'$ref', :Error
          end
        end
      end
    end
  end
end
