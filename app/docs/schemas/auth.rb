# frozen_string_literal: true

require 'swagger/blocks'

class AuthSchemas
  include Swagger::Blocks

  swagger_schema :User do
    key :type, :object
    property :id do
      key :type, :integer
    end
    property :email do
      key :type, :string
      key :format, :email
    end
    property :name do
      key :type, :string
    end
    property :avatar_url do
      key :type, :string
      key :format, :uri
    end
    property :admin do
      key :type, :boolean
    end
  end

  swagger_schema :AuthStatus do
    key :type, :object
    property :logged_in do
      key :type, :boolean
    end
    property :user do
      key :'$ref', :User
    end
  end
end
