# frozen_string_literal: true

require 'swagger/blocks'

class CommentSchemas
  include Swagger::Blocks

  swagger_schema :Comment do
    key :type, :object
    property :id do
      key :type, :integer
    end
    property :author_name do
      key :type, :string
    end
    property :author_url do
      key :type, :string
      key :nullable, true
    end
    property :content do
      key :type, :string
    end
    property :created_at do
      key :type, :string
      key :format, 'date-time'
    end
  end

  swagger_schema :AdminComment do
    key :type, :object
    property :id do
      key :type, :integer
    end
    property :post_id do
      key :type, :integer
    end
    property :author_name do
      key :type, :string
    end
    property :author_email do
      key :type, :string
    end
    property :author_url do
      key :type, :string
      key :nullable, true
    end
    property :content do
      key :type, :string
    end
    property :ip_address do
      key :type, :string
    end
    property :recaptcha_score do
      key :type, :number
      key :format, :float
    end
    property :approved do
      key :type, :boolean
    end
    property :spam do
      key :type, :boolean
    end
    property :post do
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
    property :created_at do
      key :type, :string
      key :format, 'date-time'
    end
  end

  swagger_schema :CommentInput do
    key :type, :object
    key :required, [:author_name, :author_email, :content, :recaptcha_token]
    property :author_name do
      key :type, :string
      key :maxLength, 100
    end
    property :author_email do
      key :type, :string
      key :format, :email
    end
    property :author_url do
      key :type, :string
      key :format, :uri
    end
    property :content do
      key :type, :string
      key :maxLength, 5000
    end
    property :recaptcha_token do
      key :type, :string
      key :description, 'reCAPTCHA v3 token'
    end
  end

  swagger_schema :CommentList do
    key :type, :object
    property :comments do
      key :type, :array
      items do
        key :'$ref', :Comment
      end
    end
    property :pagination do
      key :'$ref', :Pagination
    end
  end

  swagger_schema :AdminCommentList do
    key :type, :object
    property :comments do
      key :type, :array
      items do
        key :'$ref', :AdminComment
      end
    end
  end

  swagger_schema :PendingCount do
    key :type, :object
    property :count do
      key :type, :integer
    end
  end
end
