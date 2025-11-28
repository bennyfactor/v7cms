# frozen_string_literal: true

require 'swagger/blocks'

class SettingsSchemas
  include Swagger::Blocks

  swagger_schema :Settings do
    key :type, :object
    property :site_title do
      key :type, :string
    end
    property :site_tagline do
      key :type, :string
    end
    property :site_author do
      key :type, :string
    end
    property :welcome_title do
      key :type, :string
    end
    property :welcome_subtitle do
      key :type, :string
    end
    property :footer_text do
      key :type, :string
    end
    property :show_copyright_year do
      key :type, :boolean
    end
    property :meta_description do
      key :type, :string
    end
    property :meta_keywords do
      key :type, :string
    end
    property :contact_email do
      key :type, :string
      key :format, :email
    end
    property :github_url do
      key :type, :string
      key :format, :uri
    end
    property :social_url do
      key :type, :string
      key :format, :uri
    end
    property :posts_per_page do
      key :type, :integer
      key :minimum, 1
      key :maximum, 100
    end
    property :date_format do
      key :type, :string
    end
    property :allow_comments do
      key :type, :boolean
    end
  end

  swagger_schema :SettingsInput do
    key :type, :object
    property :site_title do
      key :type, :string
      key :maxLength, 200
    end
    property :site_tagline do
      key :type, :string
      key :maxLength, 500
    end
    property :site_author do
      key :type, :string
      key :maxLength, 200
    end
    property :welcome_title do
      key :type, :string
      key :maxLength, 200
    end
    property :welcome_subtitle do
      key :type, :string
      key :maxLength, 500
    end
    property :footer_text do
      key :type, :string
      key :maxLength, 500
    end
    property :show_copyright_year do
      key :type, :boolean
    end
    property :meta_description do
      key :type, :string
      key :maxLength, 500
    end
    property :meta_keywords do
      key :type, :string
      key :maxLength, 500
    end
    property :contact_email do
      key :type, :string
      key :format, :email
    end
    property :github_url do
      key :type, :string
      key :format, :uri
    end
    property :social_url do
      key :type, :string
      key :format, :uri
    end
    property :posts_per_page do
      key :type, :integer
      key :minimum, 1
      key :maximum, 100
    end
    property :date_format do
      key :type, :string
    end
    property :allow_comments do
      key :type, :boolean
    end
  end

  swagger_schema :SettingsResponse do
    key :type, :object
    property :settings do
      key :'$ref', :Settings
    end
  end
end
