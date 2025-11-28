# frozen_string_literal: true

require 'swagger/blocks'

class ThemePaths
  include Swagger::Blocks

  swagger_path '/api/theme' do
    operation :get do
      key :summary, 'Get theme'
      key :description, 'Returns current theme settings'
      key :operationId, 'getTheme'
      key :tags, ['Theme']

      response 200 do
        key :description, 'Theme settings'
        content 'application/json' do
          schema do
            key :'$ref', :ThemeResponse
          end
        end
      end
    end

    operation :put do
      key :summary, 'Update theme'
      key :description, 'Update theme settings. Requires authentication. Triggers CSS regeneration.'
      key :operationId, 'updateTheme'
      key :tags, ['Theme']

      request_body do
        key :required, true
        content 'application/json' do
          schema do
            key :'$ref', :Theme
          end
        end
      end

      response 200 do
        key :description, 'Theme updated successfully'
        content 'application/json' do
          schema do
            key :'$ref', :ThemeResponse
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

  swagger_path '/api/theme/reset' do
    operation :post do
      key :summary, 'Reset theme'
      key :description, 'Reset theme to default values. Requires authentication.'
      key :operationId, 'resetTheme'
      key :tags, ['Theme']

      response 200 do
        key :description, 'Theme reset to defaults'
        content 'application/json' do
          schema do
            key :'$ref', :ThemeResponse
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

  swagger_path '/api/theme/preview' do
    operation :get do
      key :summary, 'Preview theme'
      key :description, 'Preview theme with custom parameters without saving. Returns rendered HTML page.'
      key :operationId, 'previewTheme'
      key :tags, ['Theme']

      parameter do
        key :name, :page
        key :in, :query
        key :description, 'Page to preview (/, /posts/slug, /pages/slug)'
        key :required, false
        schema do
          key :type, :string
          key :default, '/'
        end
      end
      parameter do
        key :name, :primary_color
        key :in, :query
        key :description, 'Primary color (hex)'
        key :required, false
        schema do
          key :type, :string
        end
      end
      parameter do
        key :name, :background_color
        key :in, :query
        key :description, 'Background color (hex)'
        key :required, false
        schema do
          key :type, :string
        end
      end

      response 200 do
        key :description, 'Rendered HTML page with preview theme'
        content 'text/html' do
          schema do
            key :type, :string
          end
        end
      end
    end
  end
end
