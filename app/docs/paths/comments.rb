# frozen_string_literal: true

require 'swagger/blocks'

class CommentPaths
  include Swagger::Blocks

  swagger_path '/api/posts/{id}/comments' do
    operation :get do
      key :summary, 'List post comments'
      key :description, 'Returns approved comments for a post with pagination'
      key :operationId, 'listPostComments'
      key :tags, ['Comments']

      parameter do
        key :name, :id
        key :in, :path
        key :description, 'Post ID'
        key :required, true
        schema do
          key :type, :integer
        end
      end
      parameter do
        key :name, :limit
        key :in, :query
        key :description, 'Number of comments to return (default: 20)'
        key :required, false
        schema do
          key :type, :integer
          key :default, 20
        end
      end
      parameter do
        key :name, :offset
        key :in, :query
        key :description, 'Number of comments to skip'
        key :required, false
        schema do
          key :type, :integer
          key :default, 0
        end
      end

      response 200 do
        key :description, 'List of approved comments'
        content 'application/json' do
          schema do
            key :'$ref', :CommentList
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

    operation :post do
      key :summary, 'Submit comment'
      key :description, 'Submit a new comment. Requires reCAPTCHA v3 token. Comments are held for moderation.'
      key :operationId, 'createComment'
      key :tags, ['Comments']

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
            key :'$ref', :CommentInput
          end
        end
      end

      response 200 do
        key :description, 'Comment submitted successfully (pending moderation)'
        content 'application/json' do
          schema do
            key :'$ref', :Success
          end
        end
      end
      response 400 do
        key :description, 'Validation error or reCAPTCHA failed'
        content 'application/json' do
          schema do
            key :'$ref', :Error
          end
        end
      end
      response 403 do
        key :description, 'Comments are disabled'
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

  swagger_path '/api/comments' do
    operation :get do
      key :summary, 'List all comments (admin)'
      key :description, 'Returns all comments with full details. Requires authentication.'
      key :operationId, 'listAllComments'
      key :tags, ['Comments']

      parameter do
        key :name, :status
        key :in, :query
        key :description, 'Filter by status'
        key :required, false
        schema do
          key :type, :string
          key :enum, ['pending', 'approved', 'spam']
        end
      end

      response 200 do
        key :description, 'List of comments with admin details'
        content 'application/json' do
          schema do
            key :'$ref', :AdminCommentList
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
    end
  end

  swagger_path '/api/comments/pending_count' do
    operation :get do
      key :summary, 'Get pending comment count'
      key :description, 'Returns the number of comments awaiting moderation'
      key :operationId, 'getPendingCount'
      key :tags, ['Comments']

      response 200 do
        key :description, 'Pending comment count'
        content 'application/json' do
          schema do
            key :'$ref', :PendingCount
          end
        end
      end
    end
  end

  swagger_path '/api/comments/{id}/approve' do
    operation :put do
      key :summary, 'Approve comment'
      key :description, 'Approve a comment for display. Requires authentication.'
      key :operationId, 'approveComment'
      key :tags, ['Comments']

      parameter do
        key :name, :id
        key :in, :path
        key :description, 'Comment ID'
        key :required, true
        schema do
          key :type, :integer
        end
      end

      response 200 do
        key :description, 'Comment approved'
        content 'application/json' do
          schema do
            key :'$ref', :AdminComment
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
        key :description, 'Comment not found'
        content 'application/json' do
          schema do
            key :'$ref', :Error
          end
        end
      end
    end
  end

  swagger_path '/api/comments/{id}/spam' do
    operation :put do
      key :summary, 'Mark comment as spam'
      key :description, 'Mark a comment as spam. Requires authentication.'
      key :operationId, 'markCommentSpam'
      key :tags, ['Comments']

      parameter do
        key :name, :id
        key :in, :path
        key :description, 'Comment ID'
        key :required, true
        schema do
          key :type, :integer
        end
      end

      response 200 do
        key :description, 'Comment marked as spam'
        content 'application/json' do
          schema do
            key :'$ref', :AdminComment
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
        key :description, 'Comment not found'
        content 'application/json' do
          schema do
            key :'$ref', :Error
          end
        end
      end
    end
  end

  swagger_path '/api/comments/{id}' do
    operation :delete do
      key :summary, 'Delete comment'
      key :description, 'Permanently delete a comment. Requires authentication.'
      key :operationId, 'deleteComment'
      key :tags, ['Comments']

      parameter do
        key :name, :id
        key :in, :path
        key :description, 'Comment ID'
        key :required, true
        schema do
          key :type, :integer
        end
      end

      response 200 do
        key :description, 'Comment deleted'
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
        key :description, 'Comment not found'
        content 'application/json' do
          schema do
            key :'$ref', :Error
          end
        end
      end
    end
  end
end
