# frozen_string_literal: true

require 'swagger/blocks'

class PostPaths
  include Swagger::Blocks

  swagger_path '/api/posts' do
    operation :get do
      key :summary, 'List posts'
      key :description, 'Returns a paginated list of posts. By default returns only published posts. Authenticated users can include drafts.'
      key :operationId, 'listPosts'
      key :tags, ['Posts']

      parameter do
        key :name, :include_drafts
        key :in, :query
        key :description, 'Include unpublished posts (requires authentication)'
        key :required, false
        schema do
          key :type, :boolean
        end
      end
      parameter do
        key :name, :slug
        key :in, :query
        key :description, 'Filter by slug'
        key :required, false
        schema do
          key :type, :string
        end
      end
      parameter do
        key :name, :limit
        key :in, :query
        key :description, 'Number of posts to return (default: 20, max: 100)'
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
        key :description, 'Number of posts to skip'
        key :required, false
        schema do
          key :type, :integer
          key :default, 0
        end
      end

      response 200 do
        key :description, 'List of posts with pagination'
        content 'application/json' do
          schema do
            key :'$ref', :PostList
          end
        end
      end
    end

    operation :post do
      key :summary, 'Create post'
      key :description, 'Create a new blog post. Requires authentication.'
      key :operationId, 'createPost'
      key :tags, ['Posts']

      request_body do
        key :required, true
        content 'application/json' do
          schema do
            key :'$ref', :PostInput
          end
        end
      end

      response 201 do
        key :description, 'Post created successfully'
        content 'application/json' do
          schema do
            key :'$ref', :Post
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

  swagger_path '/api/posts/{id}' do
    operation :get do
      key :summary, 'Get post'
      key :description, 'Get a single post by ID or slug'
      key :operationId, 'getPost'
      key :tags, ['Posts']

      parameter do
        key :name, :id
        key :in, :path
        key :description, 'Post ID or slug'
        key :required, true
        schema do
          key :type, :string
        end
      end

      response 200 do
        key :description, 'Post details'
        content 'application/json' do
          schema do
            key :'$ref', :Post
          end
        end
      end
      response 404 do
        key :description, 'Post not found'
        content 'application/json' do
          schema do
            key :'$ref', :Error
          end
        end
      end
    end

    operation :put do
      key :summary, 'Update post'
      key :description, 'Update an existing post. Requires authentication.'
      key :operationId, 'updatePost'
      key :tags, ['Posts']

      parameter do
        key :name, :id
        key :in, :path
        key :description, 'Post ID'
        key :required, true
        schema do
          key :type, :integer
        end
      end

      request_body do
        key :required, true
        content 'application/json' do
          schema do
            key :'$ref', :PostInput
          end
        end
      end

      response 200 do
        key :description, 'Post updated successfully'
        content 'application/json' do
          schema do
            key :'$ref', :Post
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
        key :description, 'Post not found'
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
      key :summary, 'Delete post'
      key :description, 'Delete a post. Requires authentication.'
      key :operationId, 'deletePost'
      key :tags, ['Posts']

      parameter do
        key :name, :id
        key :in, :path
        key :description, 'Post ID'
        key :required, true
        schema do
          key :type, :integer
        end
      end

      response 200 do
        key :description, 'Post deleted successfully'
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
        key :description, 'Post not found'
        content 'application/json' do
          schema do
            key :'$ref', :Error
          end
        end
      end
    end
  end
end
