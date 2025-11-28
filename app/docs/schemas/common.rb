# frozen_string_literal: true

require 'swagger/blocks'

class CommonSchemas
  include Swagger::Blocks

  swagger_schema :Pagination do
    key :type, :object
    property :total do
      key :type, :integer
      key :description, 'Total number of items'
    end
    property :limit do
      key :type, :integer
      key :description, 'Items per page'
    end
    property :offset do
      key :type, :integer
      key :description, 'Number of items skipped'
    end
    property :has_more do
      key :type, :boolean
      key :description, 'Whether more items exist'
    end
  end

  swagger_schema :Error do
    key :type, :object
    key :required, [:error]
    property :error do
      key :type, :string
      key :description, 'Error message'
    end
  end

  swagger_schema :Success do
    key :type, :object
    property :success do
      key :type, :boolean
    end
    property :message do
      key :type, :string
    end
  end
end
